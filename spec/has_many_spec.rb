# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)

shared_examples "has_many example" do |parameter|
    before :all do
        @context = parameter[:context].to_s

        @rating_test_class = Kernel.const_get("Rating#{@context.camelize}Test".classify)
        @object_test_class = Kernel.const_get("Object#{@context.camelize}Test".classify)
        @object_rating_test_class = Kernel.const_get("ObjectRating#{@context.camelize}Test".classify)

        @rating_test_class.ensure_design_document!
        @object_test_class.ensure_design_document!
        @object_rating_test_class.ensure_design_document!
    end

    after :each do
        @rating_test_class.all.stream(&:delete)
        @object_test_class.all.stream(&:delete)
        @object_rating_test_class.all.stream(&:delete)
    end

    it "should return matching results" do
        first = @object_test_class.create! name: :bob
        second = @object_test_class.create! name: :jane

        rate = @rating_test_class.create! rating: :awesome, "object_#{@context}_test": first
        @rating_test_class.create! rating: :bad, "object_#{@context}_test": second
        @rating_test_class.create! rating: :good, "object_#{@context}_test": first

        expect(rate.try("object_#{@context}_test_id")).to eq(first.id)
        expect(@rating_test_class.respond_to?(:"find_by_object_#{@context}_test_id")).to be(true)
        expect(first.respond_to?(:"rating_#{@context}_tests")).to be(true)

        docs = first.try(:"rating_#{@context}_tests").collect(&:rating)

        expect(docs).to eq([1, 2])

        first.destroy
        expect { @rating_test_class.find rate.id }.to raise_error(::Libcouchbase::Error::KeyNotFound)
        expect(@rating_test_class.all.count).to be(1)
    end

    it "should work through a join model" do
        first = @object_test_class.create! name: :bob
        second = @object_test_class.create! name: :jane

        rate1 = @rating_test_class.create! rating: :awesome, "object_#{@context}_test": first
        rate2 = @rating_test_class.create! rating: :bad, "object_#{@context}_test": second
        rate3 = @rating_test_class.create! rating: :good, "object_#{@context}_test": first

        ort = @object_rating_test_class.create! "object_#{@context}_test": first, "rating_#{@context}_test": rate1
        @object_rating_test_class.create! "object_#{@context}_test": second, "rating_#{@context}_test": rate1

        expect(ort.try(:"rating_#{@context}_test_id".to_sym)).to eq(rate1.id)
        expect(rate1.respond_to?(:"object_#{@context}_tests")).to be(true)
        docs = rate1.try(:"object_#{@context}_tests").collect(&:name)

        expect(docs).to match_array(['bob', 'jane'])
    end
end

describe CouchbaseOrm::HasMany do
    context 'with view' do
        class ObjectRatingViewTest < CouchbaseOrm::Base
            join :object_view_test, :rating_view_test
            view :all
        end

        class RatingViewTest < CouchbaseOrm::Base
            enum rating: [:awesome, :good, :okay, :bad], default: :okay
            belongs_to :object_view_test

            has_many :object_view_tests, through: :object_rating_view_test
            view :all
        end

        class ObjectViewTest < CouchbaseOrm::Base
            attribute :name, type: String
            has_many :rating_view_tests, dependent: :destroy

            view :all
        end

        include_examples("has_many example", context: :view)
    end

    context 'with n1ql' do
        class ObjectRatingN1qlTest < CouchbaseOrm::Base
            join :object_n1ql_test, :rating_n1ql_test
            n1ql :all
        end

        class RatingN1qlTest < CouchbaseOrm::Base
            enum rating: [:awesome, :good, :okay, :bad], default: :okay
            belongs_to :object_n1ql_test

            has_many :object_n1ql_tests, through: :object_rating_n1ql_test, type: :n1ql
            n1ql :all
        end

        class ObjectN1qlTest < CouchbaseOrm::Base
            attribute :name, type: String
            has_many :rating_n1ql_tests, dependent: :destroy, type: :n1ql
            n1ql :all
        end

        include_examples("has_many example", context: :n1ql)
    end
end
