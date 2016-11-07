module CouchbaseOrm
    module HasMany
        private

        # :foreign_key, :class_name, :through
        def has_many(model, class_name: nil, foreign_key: nil, through: nil, through_class: nil, through_key: nil, **options)
            class_name  = (class_name || model.to_s.singularize.camelcase).to_s
            foreign_key = (foreign_key || ActiveSupport::Inflector.foreign_key(self.name)).to_sym

            if through || through_class
                remote_class = class_name
                class_name = (through_class || through.to_s.camelcase).to_s
                through_key = (through_key || "#{remote_class.underscore}_id").to_sym
                remote_method = :"by_#{foreign_key}_with_#{through_key}"
            else
                remote_method = :"find_by_#{foreign_key}"
            end

            relset_varname = "@#{model}_rel_set"

            klass = begin
                class_name.constantize
            rescue NameError => e
                puts "WARNING: #{class_name} referenced in #{self.name} before it was loaded"

                # Open the class early - load order will have to be changed to prevent this.
                # Warning notice required as a misspelling will not raise an error
                Object.class_eval <<-EKLASS
                    class #{class_name} < CouchbaseOrm::Base
                        attribute :#{foreign_key}
                    end
                EKLASS
                class_name.constantize
            end


            if remote_class
                klass.class_eval do
                    view remote_method, map: <<-EMAP
                        function(doc) {
                            if (doc.type === "#{klass.design_document}" && doc.#{through_key}) {
                                emit(doc.#{foreign_key}, null);
                            }
                        }
                    EMAP
                end

                define_method(model) do
                    return self.instance_variable_get(relset_varname) if instance_variable_defined?(relset_varname)

                    remote_klass = remote_class.constantize
                    enum = klass.__send__(remote_method, key: self.id) { |row|
                        remote_klass.find(row.value[through_key])
                    }

                    self.instance_variable_set(relset_varname, enum)
                end
            else
                klass.class_eval do
                    index_view foreign_key
                end

                define_method(model) do
                    return self.instance_variable_get(relset_varname) if instance_variable_defined?(relset_varname)
                    self.instance_variable_set(relset_varname, klass.__send__(remote_method, self.id))
                end
            end

            @associations ||= []
            @associations << [model, options[:dependent]]
        end
    end
end
