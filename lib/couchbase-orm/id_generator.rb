# frozen_string_literal: true, encoding: ASCII-8BIT

require 'radix/base'

module CouchbaseOrm
    class IdGenerator
        # Using base 65 as a form of compression (reduced length of ID string)
        # No escape characters are required to display these in a URL
        B65 = ::Radix::Base.new(::Radix::BASE::B62 + ['-', '_', '~'])
        B10 = ::Radix::Base.new(10)

        # We don't really care about dates before this library was created
        # This reduces the length of the ID significantly
        Skip46Years = 1451649600  # 46.years.to_i

        # Generate a unique, orderable, ID using minimal bytes
        def self.next(model)
            # We are unlikely to see a clash here
            now = Time.now
            time = (now.to_i - Skip46Years) * 1_000_000 + now.usec

            # This makes it very very improbable that there will ever be an ID clash
            # Distributed system safe!
            prefix = time.to_s
            tail = (rand(9999) + 1).to_s.rjust(4, '0')

            "#{model.class.design_document}-#{Radix.convert("#{prefix}#{tail}", B10, B65)}"
        end
    end
end
