# frozen_string_literal: true, encoding: ASCII-8BIT

require 'couchbase-orm/proxies/results_proxy'

module CouchbaseOrm
    class N1qlProxy
        def initialize(proxyfied)
            @proxyfied = proxyfied

            self.class.define_method(:results) do |*params, &block|
                @results = nil if @current_query != self.to_s
                @current_query = self.to_s
                return @results if @results

                CouchbaseOrm.logger.debug 'Query - ' + self.to_s
                @results = ResultsProxy.new(@proxyfied.results(*params, &block))
            end

            self.class.define_method(:to_s) do
                @proxyfied.to_s.tr("\n", ' ')
            end

            proxyfied.public_methods.each do |method|
                next if self.public_methods.include?(method)

                self.class.define_method(method) do |*params, &block|
                    ret = @proxyfied.send(method, *params, &block)
                    ret.is_a?(@proxyfied.class) ? self : ret
                end
            end
        end

        def method_missing(m, *args, &block)
            self.results.send(m, *args, &block)
        end
    end
end
