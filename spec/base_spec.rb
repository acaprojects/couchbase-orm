# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class BaseTest < CouchbaseOrm::Base
    attribute :name, :job
end

class CompareTest < CouchbaseOrm::Base
    attribute :age
end



describe CouchbaseOrm::Base do
    it "should be comparable to other objects" do
        base  = BaseTest.create!(name: 'joe')
        base2 = BaseTest.create!(name: 'joe')

        expect(base).to eq(base)
        expect(base).to be(base)
        expect(base).not_to eq(base2)

        same_base = BaseTest.find(base.id)
        expect(base).to eq(same_base)
        expect(base).not_to be(same_base)
        expect(base2).not_to eq(same_base)

        base.delete
        base2.delete
    end

    it "should load database responses" do
        base = BaseTest.create!(name: 'joe')
        resp = BaseTest.bucket.get(base.id, extended: true)

        expect(resp.key).to eq(base.id)

        base_loaded = BaseTest.new(resp)
        expect(base_loaded).to     eq(base)
        expect(base_loaded).not_to be(base)

        base.destroy
    end

    it "should not load objects if there is a type mismatch" do
        base = BaseTest.create!(name: 'joe')

        expect { CompareTest.find_by_id(base.id) }.to raise_error(RuntimeError)

        base.destroy
    end

    it "should support serialisation" do
        base = BaseTest.create!(name: 'joe')

        base_id = base.id
        expect(base.to_json).to eq({name: 'joe', job: nil, id: base_id}.to_json)
        expect(base.to_json(only: :name)).to eq({name: 'joe'}.to_json)

        base.destroy
    end

    describe BaseTest do
        it_behaves_like "ActiveModel"
    end

    describe CompareTest do
        it_behaves_like "ActiveModel"
    end
end
