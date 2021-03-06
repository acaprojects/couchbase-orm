# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class ObjectRatingTest < CouchbaseOrm::Base
    join :object_test, :rating_test
    view :all
end

class RatingTest < CouchbaseOrm::Base
    enum rating: [:awesome, :good, :okay, :bad], default: :okay
    belongs_to :object_test

    has_many :object_tests, through: :object_rating_test
    view :all
end

class ObjectTest < CouchbaseOrm::Base
    attribute :name, type: String
    has_many :rating_tests, dependent: :destroy

    view :all
end


describe CouchbaseOrm::HasMany do
    before :all do
        RatingTest.ensure_design_document!
        ObjectTest.ensure_design_document!
        ObjectRatingTest.ensure_design_document!
    end

    after :each do
        ObjectTest.all.stream { |ob| ob.delete }
        RatingTest.all.stream { |ob| ob.delete }
        ObjectRatingTest.all.stream { |ob| ob.delete }
    end

    it "should return matching results" do
        first = ObjectTest.create! name: :bob
        second = ObjectTest.create! name: :jane

        rate = RatingTest.create! rating: :awesome, object_test: first
        RatingTest.create! rating: :bad, object_test: second
        RatingTest.create! rating: :good, object_test: first

        expect(rate.object_test_id).to eq(first.id)
        expect(RatingTest.respond_to?(:find_by_object_test_id)).to be(true)
        expect(first.respond_to?(:rating_tests)).to be(true)

        docs = first.rating_tests.collect { |ob|
            ob.rating
        }

        expect(docs).to eq([1, 2])

        first.destroy
        expect { RatingTest.find rate.id }.to raise_error(::Libcouchbase::Error::KeyNotFound)
        expect(RatingTest.all.count).to be(1)
    end

    it "should work through a join model" do
        first = ObjectTest.create! name: :bob
        second = ObjectTest.create! name: :jane

        rate1 = RatingTest.create! rating: :awesome, object_test: first
        rate2 = RatingTest.create! rating: :bad, object_test: second
        rate3 = RatingTest.create! rating: :good, object_test: first

        ort = ObjectRatingTest.create! object_test: first, rating_test: rate1
        ObjectRatingTest.create! object_test: second, rating_test: rate1

        expect(ort.rating_test_id).to eq(rate1.id)
        expect(rate1.respond_to?(:object_tests)).to be(true)
        docs = rate1.object_tests.collect { |ob|
            ob.name
        }

        expect(docs).to eq(['bob', 'jane'])
    end
end
