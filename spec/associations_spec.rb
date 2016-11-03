# frozen_string_literal: true, encoding: ASCII-8BIT

require 'couchbase-orm'


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

        expect { Parent.find(id) }.to raise_error(Libcouchbase::Error::KeyNotFound)
        expect(Parent.find_by_id(id)).to be(nil)

        expect { parent.reload }.to raise_error(Libcouchbase::Error::KeyNotFound)

        parent.name = 'should fail'
        expect { parent.save  }.to raise_error(Libcouchbase::Error::KeyNotFound)
        expect { parent.save! }.to raise_error(Libcouchbase::Error::KeyNotFound)
    end
end
