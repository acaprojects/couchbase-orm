# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)


class ViewTest < CouchbaseOrm::Base
    attribute :name, type: String
    enum rating: [:awesome, :good, :okay, :bad], default: :okay

    view :all
    view :by_rating, emit_key: :rating
end


describe CouchbaseOrm::Views do
    it "should save a new design document" do
        ViewTest.bucket.delete_design_doc(ViewTest.design_document)
        expect(ViewTest.ensure_design_document!).to be(true)
    end

    it "should not re-save a design doc if nothing has changed" do
        expect(ViewTest.ensure_design_document!).to be(false)
    end

    it "should perform a map-reduce and return the view" do
        ViewTest.ensure_design_document!
        mod = ViewTest.create! name: :bob, rating: :good

        docs = ViewTest.all.collect { |ob|
            ob.destroy
            ob.name
        }
        expect(docs).to eq(['bob'])
    end

    it "should work with other keys" do
        ViewTest.ensure_design_document!
        ViewTest.create! name: :bob,  rating: :good
        ViewTest.create! name: :jane, rating: :awesome
        ViewTest.create! name: :greg, rating: :bad

        docs = ViewTest.by_rating(descending: :true).collect { |ob|
            ob.destroy
            ob.name
        }
        expect(docs).to eq(['greg', 'bob', 'jane'])
    end
end
