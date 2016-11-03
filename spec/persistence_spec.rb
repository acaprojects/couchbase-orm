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

class ModelWithCallbacks < CouchbaseOrm::Base
    attribute :name, :address, :age

    before_create :update_name
    before_save   :set_address
    before_update :set_age
    after_initialize do
        self.age = 10
    end
    before_destroy do
        self.name = 'joe'
    end

    def update_name; self.name = 'bob'; end
    def set_address; self.address = '23'; end
    def set_age; self.age = 30; end
end

class ModelWithValidations < CouchbaseOrm::Base
    attribute :name, :address, type: String
    attribute :age, type: :Integer

    validates :name, presence: true
    validates :age,  numericality: { only_integer: true }
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
        expect(result).to be(true)
        
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
        expect(result).to be(true)

        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(true)

        model.destroy
        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(true)
        expect(model.persisted?).to be(false)
    end

    it "should execute callbacks" do
        model = ModelWithCallbacks.new

        # Test initialize
        expect(model.name).to be(nil)
        expect(model.age).to be(10)
        expect(model.address).to be(nil)

        expect(model.new_record?).to be(true)
        expect(model.destroyed?).to be(false)
        expect(model.persisted?).to be(false)

        # Test create
        result = model.save
        expect(result).to be(true)

        expect(model.name).to eq('bob')
        expect(model.age).to be(10)
        expect(model.address).to eq('23')

        # Test Update
        model.address = 'other'
        expect(model.address).to eq('other')
        model.save

        expect(model.name).to eq('bob')
        expect(model.age).to be(30)
        expect(model.address).to eq('23')

        # Test destroy
        model.destroy
        expect(model.new_record?).to be(false)
        expect(model.destroyed?).to be(true)
        expect(model.persisted?).to be(false)

        expect(model.name).to eq('joe')
    end

    it "should perform validations" do
        model = ModelWithValidations.new

        expect(model.valid?).to be(false)

        # Test create
        result = model.save
        expect(result).to be(false)
        expect(model.errors.count).to be(2)

        begin
            model.save!
        rescue ::CouchbaseOrm::Error::RecordInvalid => e
            expect(e.record).to be(model)
        end

        model.name = 'bob'
        model.age = 23
        expect(model.valid?).to be(true)
        expect(model.save).to be(true)

        # Test update
        model.name = nil
        expect(model.valid?).to be(false)
        expect(model.save).to be(false)
        begin
            model.save!
        rescue ::CouchbaseOrm::Error::RecordInvalid => e
            expect(e.record).to be(model)
        end

        model.age = '23'    # This value will be coerced
        model.name = 'joe'
        expect(model.valid?).to be(true)
        expect(model.save!).to be(model)

        # coercion will fail here
        begin
            model.age = 'a23'
            expect(false).to be(true)
        rescue ArgumentError => e
        end

        model.destroy
    end
end
