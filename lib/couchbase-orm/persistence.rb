# frozen_string_literal: true, encoding: ASCII-8BIT

require 'active_model'
require 'active_support/hash_with_indifferent_access'

module CouchbaseOrm
    module Persistence
        extend ActiveSupport::Concern


        module ClassMethods
            def create(attributes = nil, &block)
                if attributes.is_a?(Array)
                    attributes.collect { |attr| create(attr, &block) }
                else
                    instance = new(attributes, &block)
                    instance.save
                    instance
                end
            end

            def create!(attributes = nil, &block)
                if attributes.is_a?(Array)
                    attributes.collect { |attr| create!(attr, &block) }
                else
                    instance = new(attributes, &block)
                    instance.save!
                    instance
                end
            end

            # Raise an error if validation failed.
            def fail_validate!(document)
                raise Errors::RecordInvalid.new(document)
            end

            # Allow classes to overwrite the default document name
            # extend ActiveModel::Naming (included by ActiveModel::Model)
            def design_document(name = nil)
                return @design_document unless name
                @design_document = name.to_s
            end

            # Set a default design document
            def inherited(child)
                super
                child.instance_eval do
                    @design_document = child.name
                end
            end
        end


        # Returns true if this object hasn't been saved yet -- that is, a record
        # for the object doesn't exist in the database yet; otherwise, returns false.
        def new_record?
            @__metadata__.cas.nil? && @__metadata__.key.nil?
        end
        alias_method :new?, :new_record?

        # Returns true if this object has been destroyed, otherwise returns false.
        def destroyed?
            !!(@__metadata__.cas && @__metadata__.key.nil?)
        end

        # Returns true if the record is persisted, i.e. it's not a new record and it was
        # not destroyed, otherwise returns false.
        def persisted?
            # Changed? is provided by ActiveModel::Dirty
            !!@__metadata__.key
        end
        alias_method :exists?, :persisted?

        # Saves the model.
        #
        # If the model is new, a record gets created in the database, otherwise
        # the existing record gets updated.
        def save(**options)
            self.new_record? ? _create_record(**options) : _update_record(**options)
        end

        # Saves the model.
        #
        # If the model is new, a record gets created in the database, otherwise
        # the existing record gets updated.
        #
        # By default, #save! always runs validations. If any of them fail
        # CouchbaseOrm::Error::RecordInvalid gets raised, and the record won't be saved.
        def save!
            self.class.fail_validate!(self) unless self.save
            true
        end

        # Deletes the record in the database and freezes this instance to
        # reflect that no changes should be made (since they can't be
        # persisted). Returns the frozen instance.
        #
        # The record is simply removed, no callbacks are executed.
        def delete(with_cas: false, **options)
            options[:cas] = @__metadata__.cas if with_cas
            self.class.bucket.delete(@__metadata__.key, options)

            @__metadata__.key = nil
            @id = nil

            clear_changes_information
            self.freeze
            self
        end

        # Deletes the record in the database and freezes this instance to reflect
        # that no changes should be made (since they can't be persisted).
        #
        # There's a series of callbacks associated with #destroy.
        def destroy(with_cas: false, **options)
            run_callbacks :destroy do
                destroy_associations!

                options[:cas] = @__metadata__.cas if with_cas
                self.class.bucket.delete(@__metadata__.key, options)

                @__metadata__.key = nil
                @id = nil

                clear_changes_information
                self.freeze
                self
            end
        end
        alias_method :destroy!, :destroy

        # Updates a single attribute and saves the record.
        # This is especially useful for boolean flags on existing records. Also note that
        #
        # * Validation is skipped.
        # * \Callbacks are invoked.
        def update_attribute(name, value)
            public_send("#{name}=", value)
            changed? ? save(validate: false) : true
        end
        
        # Updates the attributes of the model from the passed-in hash and saves the
        # record. If the object is invalid, the saving will fail and false will be returned.
        def update(hash)
            assign_attributes(hash)
            save
        end
        alias_method :update_attributes, :update

        # Updates its receiver just like #update but calls #save! instead
        # of +save+, so an exception is raised if the record is invalid and saving will fail.
        def update!(hash)
            assign_attributes(hash) # Assign attributes is provided by ActiveModel::AttributeAssignment
            save!
        end

        # Reloads the record from the database.
        #
        # This method finds record by its key and modifies the receiver in-place:
        def reload
            key = @__metadata__.key
            raise "unable to reload, model not persisted" unless key

            resp = self.class.bucket.get(key, quiet: false, extended: true)
            @__attributes__ = ::ActiveSupport::HashWithIndifferentAccess.new(resp.value)
            @__metadata__.key = resp.key
            @__metadata__.cas = resp.cas

            reset_associations
            clear_changes_information
            self
        end

        # Updates the TTL of the document
        def touch(**options)
            res = self.class.bucket.touch(@__metadata__.key, async: false, **options)
            @__metadata__.cas = resp.cas
            self
        end


        protected


        def _update_record(with_cas: false, **options)
            raise "Cannot save a destroyed document!" if destroyed?
            raise "Calling #{self.class.name}#update on document that has not been created!" if new_record?
            return false unless perform_validations(options)
            return true unless changed?

            run_callbacks :update do
                run_callbacks :save do
                    # Ensure the type is set
                    @__attributes__[:type] = self.class.design_document
                    @__attributes__.delete(:id)

                    _id = @__metadata__.key
                    options[:cas] = @__metadata__.cas if with_cas
                    resp = self.class.bucket.replace(_id, @__attributes__, **options)
                    
                    # Ensure the model is up to date
                    @__metadata__.key = resp.key
                    @__metadata__.cas = resp.cas

                    clear_changes_information
                    self
                end
            end
        end

        def _create_record(**options)
            return false unless perform_validations(options)
            run_callbacks :create do
                run_callbacks :save do
                    # Ensure the type is set
                    @__attributes__[:type] = self.class.design_document
                    @__attributes__.delete(:id)

                    _id = @id || self.class.uuid_generator.next(self)
                    resp = self.class.bucket.add(_id, @__attributes__, **options)

                    # Ensure the model is up to date
                    @__metadata__.key = resp.key
                    @__metadata__.cas = resp.cas

                    clear_changes_information
                    self
                end
            end
        end

        def perform_validations(options = {})
            options[:validate] != false ? valid? : true
        end
    end
end
