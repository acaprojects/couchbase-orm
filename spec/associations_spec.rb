# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class Parent < CouchbaseOrm::Base
    attribute :name
end

class Child < CouchbaseOrm::Base
    attribute :name

    belongs_to :parent, dependent: :destroy
end


describe CouchbaseOrm::Associations do
    it "should work with dependent associations" do
        parent = Parent.create!(name: 'joe')
        child  = Child.create!(name: 'bob', parent_id: parent.id)

        expect(parent.persisted?).to be(true)
        expect(child.persisted?).to be(true)
        id = parent.id

        child.destroy
        expect(child.destroyed?).to be(true)
        expect(parent.destroyed?).to be(false)

        # Ensure that parent has been destroyed
        expect { Parent.find(id) }.to raise_error(Libcouchbase::Error::KeyNotFound)
        expect(Parent.find_by_id(id)).to be(nil)

        expect { parent.reload }.to raise_error(Libcouchbase::Error::KeyNotFound)

        # Save will always return true unless the model is changed (won't touch the database)
        parent.name = 'should fail'
        expect { parent.save  }.to raise_error(Libcouchbase::Error::KeyNotFound)
        expect { parent.save! }.to raise_error(Libcouchbase::Error::KeyNotFound)
    end

    it "should cache associations" do
        parent = Parent.create!(name: 'joe')
        child  = Child.create!(name: 'bob', parent_id: parent.id)

        id = child.parent.__id__
        expect(parent.__id__).not_to eq(child.parent.__id__)
        expect(parent).to eq(child.parent)
        expect(child.parent.__id__).to eq(id)

        child.reload
        expect(parent).to eq(child.parent)
        expect(child.parent.__id__).not_to eq(id)

        child.destroy
    end

    it "should ignore associations when delete is used" do
        parent = Parent.create!(name: 'joe')
        child  = Child.create!(name: 'bob', parent_id: parent.id)

        id = child.id
        child.delete

        expect(Child.exists?(id)).to be(false)
        expect(Parent.exists?(parent.id)).to be(true)

        id = parent.id
        parent.delete
        expect(Parent.exists?(id)).to be(false)
    end

    describe Parent do
        it_behaves_like "ActiveModel"
    end

    describe Child do
        it_behaves_like "ActiveModel"
    end
end
