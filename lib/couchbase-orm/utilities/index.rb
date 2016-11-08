module CouchbaseOrm
    module Index
        private

        def index(attrs, name = nil, &processor)
            attrs = Array(attrs).flatten
            name ||= attrs.map(&:to_s).join('_')

            find_by_method          = "find_by_#{name}"
            processor_method        = "process_#{name}"
            bucket_key_method       = "#{name}_bucket_key"
            bucket_key_vals_method  = "#{name}_bucket_key_vals"
            class_bucket_key_method = "generate_#{bucket_key_method}"
            original_bucket_key_var = "@original_#{bucket_key_method}"


            #----------------
            # keys
            #----------------
            # class method to generate a bucket key given input values
            define_singleton_method(class_bucket_key_method) do |*values|
                processed = self.send(processor_method, *values)
                "#{@design_document}#{name}-#{processed}"
            end

            # instance method that uses the class method to generate a bucket key
            # given the current value of each of the key's component attributes
            define_method(bucket_key_method) do |args = nil|
                self.class.send(class_bucket_key_method, *self.send(bucket_key_vals_method))
            end

            # collect a list of values for each key component attribute
            define_method(bucket_key_vals_method) do
                attrs.collect {|attr| self[attr]}
            end


            #----------------
            # helpers
            #----------------
            # simple wrapper around the processor proc if supplied
            define_singleton_method(processor_method) do |*values|
                if processor
                    processor.call(values.length == 1 ? values.first : values)
                else
                    values.join('-')
                end
            end

            # use the bucket key as an index - lookup records by attr values
            define_singleton_method(find_by_method) do |*values|
                key = self.send(class_bucket_key_method, *values)
                id  = self.bucket.get(key, quiet: true)
                if id
                    mod = self.find_by_id(id)
                    return mod if mod

                    # Clean up record if the id doesn't exist
                    self.bucket.delete(key, quiet: true)
                end

                nil
            end


            #----------------
            # validations
            #----------------
            # ensure each component of the unique key is present
            attrs.each do |attr|
                validates attr, presence: true
                define_attribute_methods attr
            end

            define_method("#{name}_unique?") do
                values = self.send(bucket_key_vals_method)
                other  = self.class.send(find_by_method, *values)
                !other || other.id == self.id
            end


            #----------------
            # callbacks
            #----------------
            # before a save is complete, while changes are still available, store
            # a copy of the current bucket key for comparison if any of the key
            # components have been modified
            before_save do |record|
                if attrs.any? { |attr| record.changes.include?(attr) }
                    args = attrs.collect { |attr| send(:"#{attr}_was") || send(attr) }
                    instance_variable_set(original_bucket_key_var, self.class.send(class_bucket_key_method, *args))
                end
            end

            # after the values are persisted, delete the previous key and store the
            # new one. the id of the current record is used as the key's value.
            after_save do |record|
                original_key = instance_variable_get(original_bucket_key_var)
                record.class.bucket.delete(original_key, quiet: true) if original_key
                record.class.bucket.set(record.send(bucket_key_method), record.id, plain: true)
                instance_variable_set(original_bucket_key_var, nil)
            end

            # cleanup by removing the bucket key before the record is deleted
            # TODO: handle unpersisted, modified component values
            before_destroy do |record|
                record.class.bucket.delete(record.send(bucket_key_method), quiet: true)
                true
            end

            # return the name used to construct the added method names so other
            # code can call the special index methods easily
            return name
        end

    end
end
