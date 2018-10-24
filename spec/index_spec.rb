# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class IndexTest < CouchbaseOrm::Base
    attribute :email, type: String
    attribute :name,  type: String, default: :joe
    ensure_unique :email, presence: false
end

class EnumTest < CouchbaseOrm::Base
    enum visibility: [:group, :authority, :public], default: :authority
end


describe CouchbaseOrm::Index do
    after :each do
        IndexTest.bucket.delete('index_testemail-joe@aca.com')
        IndexTest.bucket.delete('index_testemail-')
    end

    it "should prevent models being created if they should have unique keys" do
        joe = IndexTest.create!(email: 'joe@aca.com')
        expect { IndexTest.create!(email: 'joe@aca.com') }.to raise_error(CouchbaseOrm::Error::RecordInvalid)

        joe.email = 'other@aca.com'
        joe.save
        other = IndexTest.new(email: 'joe@aca.com')
        expect(other.save).to be(true)

        expect { IndexTest.create!(email: 'joe@aca.com') }.to raise_error(CouchbaseOrm::Error::RecordInvalid)
        expect { IndexTest.create!(email: 'other@aca.com') }.to raise_error(CouchbaseOrm::Error::RecordInvalid)

        joe.destroy
        other.destroy

        again = IndexTest.new(email: 'joe@aca.com')
        expect(again.save).to be(true)

        again.destroy
    end

    it "should provide helper methods for looking up the model" do
        joe = IndexTest.create!(email: 'joe@aca.com')

        joe_again = IndexTest.find_by_email('joe@aca.com')
        expect(joe).to eq(joe_again)

        joe.destroy
    end

    it "should clean up itself if dangling keys are left" do
        joe = IndexTest.create!(email: 'joe@aca.com')
        joe.delete # no callbacks are executed

        again = IndexTest.new(email: 'joe@aca.com')
        expect(again.save).to be(true)

        again.destroy
    end

    it "should work with nil values" do
        joe = IndexTest.create!
        expect(IndexTest.find_by_email(nil)).to eq(nil)

        joe.email = 'joe@aca.com'
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe)

        joe.email = nil
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(nil)
        expect(IndexTest.find_by_email(nil)).to eq(nil)

        joe.destroy
    end

    it "should work with enumerators" do
        # Test symbol
        enum = EnumTest.create!(visibility: :public)
        expect(enum.visibility).to eq(3)
        enum.destroy

        # Test number
        enum = EnumTest.create!(visibility: 2)
        expect(enum.visibility).to eq(2)
        enum.destroy

        # Test default
        enum = EnumTest.create!
        expect(enum.visibility).to eq(2)
        enum.destroy
    end

    it "should not overwrite index's that do not belong to the current model" do
        joe = IndexTest.create!
        expect(IndexTest.find_by_email(nil)).to eq(nil)

        joe.email = 'joe@aca.com'
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe)

        joe2 = IndexTest.create!
        joe2.email = 'joe@aca.com' # joe here is deliberate
        joe2.save!

        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe2)

        # Joe's indexing should not remove joe2 index
        joe.email = nil
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe2)

        # Test destroy
        joe.email = 'joe@aca.com'
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe)

        # Index should not be updated
        joe2.destroy
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(joe)

        # index should be updated
        joe.email = nil
        joe.save!
        expect(IndexTest.find_by_email('joe@aca.com')).to eq(nil)

        joe.destroy
    end
end
