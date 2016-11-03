# frozen_string_literal: true, encoding: ASCII-8BIT


require 'couchbase-orm'
require 'minitest/assertions'
require 'active_model/lint'


shared_examples_for "ActiveModel" do
    include Minitest::Assertions
    include ActiveModel::Lint::Tests

    def assertions
        @__assertions__ ||= 0
    end

    def assertions=(val)
        @__assertions__ = val
    end

    ActiveModel::Lint::Tests.public_instance_methods.map { |method| method.to_s }.grep(/^test/).each do |method|
        example(method.gsub('_', ' ')) { send method }
    end

    before do
        @model = subject
    end
end
