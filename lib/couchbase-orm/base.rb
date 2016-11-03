# frozen_string_literal: true, encoding: ASCII-8BIT


require 'active_model'
require 'active_support/hash_with_indifferent_access'
require 'couchbase-orm/error'
require 'couchbase-orm/persistence'
require 'couchbase-orm/associations'
require 'couchbase-orm/utilities/join'
require 'couchbase-orm/utilities/enum'
require 'couchbase-orm/utilities/index'
require 'couchbase-orm/utilities/has_many'
require 'couchbase-orm/utilities/ensure_unique'


module CouchbaseOrm
    class Base
        include ::ActiveModel::Model
        include ::ActiveModel::Dirty
        include ::ActiveModel::Serializers::JSON

        extend  ::ActiveModel::Callbacks
        define_model_callbacks :initialize, :only => :after
        define_model_callbacks :create, :destroy, :save, :update

        include Persistence
        include Associations
        extend Join
        extend Enum
        extend EnsureUnique
        extend HasMany
        extend Index


        Metadata = Struct.new(:key, :cas)


        def self.connect(**options)
            @bucket = ::Libcouchbase::Bucket.new(**options)
        end

        def self.bucket=(bucket)
            @bucket = bucket
        end

        def self.bucket
            @bucket ||= Connection.bucket
        end

        at_exit do
            # This will disconnect the database connection
            @bucket = nil
        end

        def self.uuid_generator
            @uuid_generator ||= IdGenerator
        end

        def self.uuid_generator=(generator)
            @uuid_generator = generator
        end

        def self.attribute(*names, **options)
            @attributes ||= {}
            names.each do |name|
                name = name.to_sym

                @attributes[name] = options
                next if self.instance_methods.include?(name)

                define_method(name) do
                    read_attribute(name)
                end

                define_method(:"#{name}=") do |value|
                    value = yield(value) if block_given?
                    write_attribute(name, value)
                end
            end
        end

        def self.attributes
            @attributes ||= {}
        end

        def self.find(*ids, **options)
            options[:extended] = true
            options[:quiet] ||= false

            ids = ids.flatten
            records = bucket.get(*ids, **options)

            records = records.is_a?(Array) ? records : [records]
            records.map! { |record|
                if record
                    self.new(record)
                else
                    false
                end
            }
            records.select! { |rec| rec }
            ids.length > 1 ? records : records[0]
        end

        def self.find_by_id(*ids, **options)
            options[:quiet] = true
            find *ids, **options
        end


        # Add support for libcouchbase response objects
        def initialize(model = nil, ignore_doc_type: false, **attributes)
            @__metadata__   = Metadata.new

            # Assign default values
            @__attributes__ = ::ActiveSupport::HashWithIndifferentAccess.new({type: self.class.design_document})
            self.class.attributes.each do |key, options|
                default = options[:default]
                if default.respond_to?(:call)
                    @__attributes__[key] = default.call
                else
                    @__attributes__[key] = default
                end
            end

            if model
                case model
                when ::Libcouchbase::Response
                    doc = model.value || raise('empty response provided')
                    type = doc.delete(:type)
                    doc.delete(:id)

                    if type && !ignore_doc_type && type.to_s != self.class.design_document
                        raise "document type mismatch, #{type} != #{self.class.design_document}"
                    end

                    @__metadata__.key = model.key
                    @__metadata__.cas = model.cas

                    # This ensures that defaults are applied
                    super(**doc)
                when CouchbaseOrm::Base
                    attributes = model.attributes
                    attributes.delete(:id)
                    super(**attributes)
                else
                    super(**attributes.merge(Hash(model)))
                end
            else
                super(**attributes)
            end

            yield self if block_given?

            run_callbacks :initialize
        end


        # Document ID is a special case as it is not stored in the document
        def id
            @__metadata__.key || @id
        end

        def id=(value)
            raise 'ID cannot be changed' if @__metadata__.cas
            attribute_will_change!(:id)
            @id = value.to_s
        end

        def read_attribute(attr_name)
            @__attributes__[attr_name]
        end
        alias_method :[], :read_attribute

        def write_attribute(attr_name, value)
            unless value.nil?
                coerce = self.class.attributes[attr_name][:type]
                value = Kernel.send(coerce.to_s, value) if coerce
            end
            attribute_will_change!(attr_name) unless @__attributes__[attr_name] == value
            @__attributes__[attr_name] = value
        end
        alias_method :[]=, :write_attribute

        #
        # Add support for Serialization:
        # http://guides.rubyonrails.org/active_model_basics.html#serialization
        #

        def attributes
            copy = @__attributes__.merge({id: id})
            copy.delete(:type)
            copy
        end

        def attributes=(attributes)
            attributes.each do |key, value|
                setter = :"#{key}="
                send(setter, value) if respond_to?(setter)
            end
        end


        #
        # Add support for comparisons
        #

        # Public: Allows for access to ActiveModel functionality.
        #
        # Returns self.
        def to_model
            self
        end

        # Public: Hashes our unique key instead of the entire object.
        # Ruby normally hashes an object to be used in comparisons.  In our case
        # we may have two techincally different objects referencing the same entity id,
        # so we will hash just the class and id (via to_key) to compare so we get the
        # expected result
        #
        # Returns a string representing the unique key.
        def hash
            "#{self.class.name}-#{self.id}-#{@__metadata__.cas}-#{@__attributes__.hash}".hash
        end

        # Public: Overrides eql? to use == in the comparison.
        #
        # other - Another object to compare to
        #
        # Returns a boolean.
        def eql?(other)
            self == other
        end

        # Public: Overrides == to compare via class and entity id.
        #
        # other - Another object to compare to
        #
        # Example
        #
        #     movie = Movie.find(1234)
        #     movie.to_key
        #     # => 'movie-1234'
        #
        # Returns a string representing the unique key.
        def ==(other)
            hash == other.hash
        end
    end
end
