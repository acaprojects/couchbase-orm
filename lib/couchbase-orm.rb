# frozen_string_literal: true, encoding: ASCII-8BIT

require 'libcouchbase'

module CouchbaseOrm
    autoload :Error,       'couchbase-orm/error'
    autoload :Connection,  'couchbase-orm/connection'
    autoload :IdGenerator, 'couchbase-orm/id_generator'
    autoload :Base,        'couchbase-orm/base'
end

# Provide Boolean conversion function
# See: http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/
module Conversions
    private

    def Boolean(value)
        case value
        when String, Symbol
            case value.to_s.strip.downcase
            when 'true'
                return true
            when 'false'
                return false
            end
        when Integer
            return value != 0
        when false, nil
            return false
        when true
            return true
        end

        raise ArgumentError, "invalid value for Boolean(): \"#{value.inspect}\""
    end
end

# If we are using Rails then we will include the Couchbase railtie.
if defined?(Rails)
    require 'couchbase-orm/railtie'
end

