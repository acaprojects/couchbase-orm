# frozen_string_literal: true, encoding: ASCII-8BIT

require 'couchbase-orm'


class BasicModel < CouchbaseOrm::Base
    attribute :name, :address, :age
end

class ModelWithDefaults < CouchbaseOrm::Base
    attribute :name, default: proc { 'bob' }
    attribute :address
    attribute :age, default: 23
end


describe CouchbaseOrm::Persistence do
    it "should save a model" do
        model = BasicModel.new

        expect(model.new_record?).to be(true)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(false)

        model.name = 'bob'
        expect(model.name).to eq('bob')

        model.address = 'somewhere'
        model.age = 34

        expect(model.new_record?).to be(true)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(false)

        result = model.save
        expect(result).to be(model)
        
        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(true)

        model.destroy
        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(true)
        expect(model.persisted?).to be(false)
    end

    it "should save a model with defaults" do
        model = ModelWithDefaults.new

        expect(model.name).to eq('bob')
        expect(model.age).to be(23)
        expect(model.address).to be(nil)

        expect(model.new_record?).to be(true)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(false)

        result = model.save
        expect(result).to be(model)

        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(true)

        model.destroy
        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(true)
        expect(model.persisted?).to be(false)
    end
end
