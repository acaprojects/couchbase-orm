# frozen_string_literal: true, encoding: ASCII-8BIT

module CouchbaseOrm
    class Error < ::StandardError
        attr_reader :record
        
        def initialize(message = nil, record = nil)
            @record = record
            super(message)
        end

        class RecordInvalid < Error; end
        class RecordExists < Error; end
    end
end
