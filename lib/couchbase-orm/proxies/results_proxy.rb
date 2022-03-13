# frozen_string_literal: true, encoding: ASCII-8BIT

module CouchbaseOrm
    class ResultsProxy
        def initialize(proxyfied)
            @proxyfied = proxyfied

            proxyfied.public_methods.each do |method|
                next if self.public_methods.include?(method)

                self.class.define_method(method) do |*params, &block|
                    @proxyfied.send(method, *params, &block)
                end
            end
        end

        def method_missing(m, *args, &block)
            @proxyfied.to_a.send(m, *args, &block)
        end
    end
end
