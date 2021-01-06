# frozen_string_literal: true

require File.expand_path("../support", __FILE__)

class N1QLTest < CouchbaseOrm::Base
    attribute :name, type: String
    enum rating: [:awesome, :good, :okay, :bad], default: :okay

    n1ql :all
    n1ql :by_name, emit_key: :name
    n1ql :by_rating, emit_key: :rating

    # This generates both:
    # view :by_rating, emit_key: :rating    # same as above
    # def self.find_by_rating(rating); end  # also provide this helper function
    index_n1ql :rating
end

describe CouchbaseOrm::N1ql do
    before(:each) do
        N1QLTest.all.each(&:destroy)
    end

    it "should perform a query and return the n1ql" do
        N1QLTest.create! name: :bob
        docs = N1QLTest.all.collect { |ob|
            ob.name
        }
        expect(docs).to eq(%w[bob])
    end

    it "should work with other keys" do
        N1QLTest.create! name: :bob, rating: :good
        N1QLTest.create! name: :jane, rating: :awesome
        N1QLTest.create! name: :greg, rating: :bad

        docs = N1QLTest.by_name(descending: true).collect { |ob|
            ob.name
        }
        expect(docs).to eq(%w[jane greg bob])

        docs = N1QLTest.by_rating(descending: true).collect { |ob|
            ob.rating
        }
        expect(docs).to eq([4, 2, 1])
    end

    it "should return matching results" do
        N1QLTest.create! name: :bob, rating: :awesome
        N1QLTest.create! name: :jane, rating: :awesome
        N1QLTest.create! name: :greg, rating: :bad
        N1QLTest.create! name: :mel, rating: :good

        docs = N1QLTest.find_by_rating(1).collect { |ob|
            ob.name
        }

        expect(Set.new(docs)).to eq(Set.new(%w[bob jane]))
    end

    after(:all) do
        N1QLTest.all.to_a.each(&:destroy)
    end
end
