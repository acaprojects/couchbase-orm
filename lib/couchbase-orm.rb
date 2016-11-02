# frozen_string_literal: true, encoding: ASCII-8BIT

require 'libcouchbase'

module CouchbaseOrm
    autoload :Error,       'couchbase-orm/error'
    autoload :Connection,  'couchbase-orm/connection'
    autoload :IdGenerator, 'couchbase-orm/id_generator'
    autoload :Base,        'couchbase-orm/base'
end
