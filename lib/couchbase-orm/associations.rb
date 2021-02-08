# frozen_string_literal: true, encoding: ASCII-8BIT

require 'active_model'

module CouchbaseOrm
    module Associations
        extend ActiveSupport::Concern


        module ClassMethods
            # Defines a belongs_to association for the model
            def belongs_to(name, **options)
                @associations ||= []
                @associations << [name.to_sym, options[:dependent]]

                ref = options[:foreign_key] || :"#{name}_id"
                ref_ass = :"#{ref}="
                instance_var = :"@__assoc_#{name}"

                # Class reference
                assoc = (options[:class_name] || name.to_s.camelize).to_s

                # Create the local setter / getter
                attribute(ref) { |value|
                    remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
                    value
                }

                # Define reader
                define_method(name) do
                    return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)
                    val = if options[:polymorphic]
                        ::CouchbaseOrm.try_load(self.send(ref))
                    else
                        assoc.constantize.find(self.send(ref), quiet: true)
                    end
                    instance_variable_set(instance_var, val)
                    val
                end

                # Define writer
                attr_writer name
                define_method(:"#{name}=") do |value|
                    if value
                        if !options[:polymorphic]
                            klass = assoc.constantize
                            raise ArgumentError, "type mismatch on association: #{klass.design_document} != #{value.class.design_document}" if klass.design_document != value.class.design_document
                        end
                        self.send(ref_ass, value.id)
                    else
                        self.send(ref_ass, nil)
                    end

                    instance_variable_set(instance_var, value)
                end
            end

            def has_and_belongs_to_many(name, **options)
                @associations ||= []
                @associations << [name.to_sym, options[:dependent]]

                ref = options[:foreign_key] || :"#{name.to_s.singularize}_ids"
                ref_ass = :"#{ref}="
                instance_var = :"@__assoc_#{name}"

                # Class reference
                assoc = (options[:class_name] || name.to_s.singularize.camelize).to_s

                # Create the local setter / getter
                attribute(ref) { |value|
                    remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
                    value
                }

                # Define reader
                define_method(name) do
                    return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)
                    val = if options[:polymorphic]
                        ::CouchbaseOrm.try_load(self.send(ref))
                    else
                        assoc.constantize.find(self.send(ref), quiet: true)
                    end
                    val = Array.wrap(val)
                    instance_variable_set(instance_var, val)
                    val
                end

                # Define writer
                attr_writer name
                define_method(:"#{name}=") do |value|
                    if value
                        if !options[:polymorphic]
                            klass = assoc.constantize
                            value.each do |v|
                                raise ArgumentError, "type mismatch on association: #{klass.design_document} != #{v.class.design_document}" if klass.design_document != v.class.design_document
                            end
                        end
                        self.send(ref_ass, value.map(&:id))
                    else
                        self.send(ref_ass, nil)
                    end

                    instance_variable_set(instance_var, value)
                end

                after_save do
                    old, new = previous_changes[ref]
                    adds = (new || []) - (old || [])
                    subs = (old || []) - (new || [])

                    update_has_and_belongs_to_many_reverse_association(name, adds, true)
                    update_has_and_belongs_to_many_reverse_association(name, subs, false)
                end if options[:autosave]
            end

            def associations
                @associations || []
            end
        end

        def update_has_and_belongs_to_many_reverse_association(name, keys, is_add)
            foreign_key = "#{self.class.to_s.underscore}_ids"
            unless keys.empty?
                self.__send__(name.to_sym)
                    .select { |v| keys.include?(v.id) }
                    .each do |v|
                        if v.respond_to?(foreign_key.to_sym)
                            tab = v.__send__(foreign_key.to_sym)
                            if is_add
                                tab = (tab || []) << self.id
                            else
                                tab = (tab || []) >> self.id
                            end
                            v.__send__(:"#{foreign_key}=", tab)
                            v.__send__(:save!)
                        end
                    end
            end
        end

        def destroy_associations!
            assoc = self.class.associations
            assoc.each do |name, dependent|
                next unless dependent

                model = self.__send__(name)
                if model.present?
                    case dependent
                    when :destroy, :delete
                        if model.respond_to?(:stream)
                            model.stream { |mod| mod.__send__(dependent) }
                        elsif model.is_a?(Array)
                            model.each { |m| m.__send__(dependent) }
                        else
                            model.__send__(dependent)
                        end
                    when :restrict_with_exception
                        raise RecordExists.new("#{self.class.name} instance maintains a restricted reference to #{name}", self)
                    when :restrict_with_error
                        # TODO::
                    end
                end
            end
        end

        def reset_associations
            assoc = self.class.associations
            assoc.each do |name, _|
                instance_var = :"@__assoc_#{name}"
                remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
            end
        end
    end
end
