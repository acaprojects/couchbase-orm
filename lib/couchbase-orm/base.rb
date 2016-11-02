# frozen_string_literal: true, encoding: ASCII-8BIT


require 'active_model'
require 'active_support/hash_with_indifferent_access'
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

        def self.attribute(*names, default: nil, **options)
            @attributes ||= {}
            names.each do |name|
                name = name.to_sym

                @attributes[name] = default
                next if self.instance_methods.include?(name)

                define_method(name) do
                    read_attribute(name)
                end

                define_method(:"#{name}=") do |value|
                    write_attribute(name, value)
                end
            end
        end

        def self.default_attributes
            @attributes
        end


        # Add support for libcouchbase response objects
        def initialize(attributes = {}, ignore_doc_type: false)
            @__metadata__   = Metadata.new

            # Assign default values
            @__attributes__ = ::ActiveSupport::HashWithIndifferentAccess.new
            self.class.default_attributes.each do |key, value|
                if value.respond_to?(:call)
                    @__attributes__[key] = value.call
                else
                    @__attributes__[key] = value
                end
            end

            if attributes.is_a? ::Libcouchbase::Response
                doc = attributes.value || raise('empty response provided')
                type = doc[:type]

                if type && !ignore_doc_type && type.to_s != self.class.design_document
                    raise "document type mismatch, #{type} != #{self.class.design_document}"
                end
                
                @__metadata__.key = attributes.key
                @__metadata__.cas = attributes.cas

                # This ensures that defaults are applied
                doc.delete(:id)
                super(**doc)
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
            attribute_will_change!(attr_name) unless @__attributes__[attr_name] == value
            @__attributes__[attr_name] = value
        end
        alias_method :[]=, :write_attribute

        #
        # Add support for Serialization:
        # http://guides.rubyonrails.org/active_model_basics.html#serialization
        #

        def attributes
            @__attributes__.merge({id: id})
        end

        def attributes=(attributes)
            attributes.each do |key, value|
                setter = :"#{key}="
                send(setter, value) if respond_to?(setter)
            end
        end

        def to_model
            self
        end
    end
end
