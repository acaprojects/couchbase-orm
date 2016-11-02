# frozen_string_literal: true, encoding: ASCII-8BIT

module CouchbaseOrm
    class Error < ::StandardError
        def initialize(*args, model: nil)
            super(*args)
            @model = model
        end

        attr_reader :model

        class RecordInvalid < Error; end
        class RecordExists < Error; end
    end
end
