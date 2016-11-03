# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class IndexTest < CouchbaseOrm::Base
    attribute :email
    ensure_unique :email
end

class EnumTest < CouchbaseOrm::Base
    enum visibility: [:group, :authority, :public], default: :authority
end


describe CouchbaseOrm::Index do
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
end
