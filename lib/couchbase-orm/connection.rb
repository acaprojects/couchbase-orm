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

        # This will disconnect the database connection,
        # allowing the application to exit
        at_exit do
            @bucket = nil
        end
    end
end
