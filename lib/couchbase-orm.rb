# frozen_string_literal: true, encoding: ASCII-8BIT

require 'libcouchbase'

module CouchbaseOrm
    autoload :Error,       'couchbase-orm/error'
    autoload :Connection,  'couchbase-orm/connection'
    autoload :IdGenerator, 'couchbase-orm/id_generator'
    autoload :Base,        'couchbase-orm/base'
end

# If we are using Rails then we will include the Couchbase railtie.
if defined?(Rails)
    require 'couchbase-orm/railtie'
end

