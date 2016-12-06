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
        base3 = BaseTest.create!(ActiveSupport::HashWithIndifferentAccess.new(name: 'joe'))

        expect(base).to eq(base)
        expect(base).to be(base)
        expect(base).not_to eq(base2)

        same_base = BaseTest.find(base.id)
        expect(base).to eq(same_base)
        expect(base).not_to be(same_base)
        expect(base2).not_to eq(same_base)

        base.delete
        base2.delete
        base3.delete
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

    it "should support dirty attributes" do
        begin
            base = BaseTest.new
            expect(base.changes.empty?).to be(true)
            expect(base.previous_changes.empty?).to be(true)

            base.name = 'change'
            expect(base.changes.empty?).to be(false)

            base = BaseTest.new({name: 'bob'})
            expect(base.changes.empty?).to be(false)
            expect(base.previous_changes.empty?).to be(true)

            # A saved model should have no changes
            base = BaseTest.create!(name: 'joe')
            expect(base.changes.empty?).to be(true)
            expect(base.previous_changes.empty?).to be(false)

            # Attributes are copied from the existing model
            base = BaseTest.new(base)
            expect(base.changes.empty?).to be(false)
            expect(base.previous_changes.empty?).to be(true)
        ensure
            base.destroy if base.id
        end
    end

    it "should try to load a model with nothing but an ID" do
        begin
            base = BaseTest.create!(name: 'joe')
            obj = CouchbaseOrm.try_load(base.id)
            expect(obj).to eq(base)
        ensure
            base.destroy
        end
    end

    describe BaseTest do
        it_behaves_like "ActiveModel"
    end

    describe CompareTest do
        it_behaves_like "ActiveModel"
    end
end
