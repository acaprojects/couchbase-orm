# frozen_string_literal: true, encoding: ASCII-8BIT

require 'couchbase-orm/proxies/n1ql_proxy'

module CouchbaseOrm
    class BucketProxy
        def initialize(proxyfied)
            @proxyfied = proxyfied

            self.class.define_method(:name) do
                @proxyfied.bucket
            end

            self.class.define_method(:n1ql) do
                N1qlProxy.new(@proxyfied.n1ql)
            end

            self.class.define_method(:view) do |design, view, **opts, &block|
                @results = nil if @current_query != "#{design}_#{view}"
                @current_query = "#{design}_#{view}"
                return @results if @results

                CouchbaseOrm.logger.debug "View - #{design} #{view}"
                @results = ResultsProxy.new(@proxyfied.send(:view, design, view, **opts, &block))
            end

            proxyfied.public_methods.each do |method|
                next if self.public_methods.include?(method)

                self.class.define_method(method) do |*params, &block|
                    @proxyfied.send(method, *params, &block)
                end
            end
        end
    end
end
