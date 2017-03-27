# frozen_string_literal: true, encoding: ASCII-8BIT

require 'libcouchbase'

module CouchbaseOrm
    class Connection
        @options = {}
        class << self
            attr_accessor :options
        end

        def self.bucket
            @bucket ||= ::Libcouchbase::Bucket.new(**@options)
        end
    end
end
