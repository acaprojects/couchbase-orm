# Couchbase ORM for Rails

[![Build Status](https://secure.travis-ci.org/acaprojects/couchbase-orm.svg)](http://travis-ci.org/acaprojects/couchbase-orm)

## Rails integration

To generate config you can use `rails generate couchbase_orm:config`:

    $ rails generate couchbase_orm:config dev_bucket dev_user dev_password
      => create  config/couchbase.yml

It will generate this `config/couchbase.yml` for you:

    common: &common
      hosts: localhost
      username: dev_user
      password: dev_password

    development:
      <<: *common
      bucket: dev_bucket

    test:
      <<: *common
      bucket: dev_bucket_test

    # set these environment variables on your production server
    production:
    hosts: <%= ENV['COUCHBASE_HOST'] || ENV['COUCHBASE_HOSTS'] %>
    bucket: <%= ENV['COUCHBASE_BUCKET'] %>
    username: <%= ENV['COUCHBASE_USER'] %>
    password: <%= ENV['COUCHBASE_PASSWORD'] %>

Views are generated on application load if they don't exist or mismatch.
This works fine in production however by default in development models are lazy loaded.

    # config/environments/development.rb
    config.eager_load = true


## Examples

```ruby
    require 'couchbase-orm'

    class Post < CouchbaseOrm::Base
      attribute :title, type: String
      attribute :body,  type: String
      attribute :draft, type: Boolean
    end

    p = Post.new(id: 'hello-world',
                 title: 'Hello world',
                 draft: true)
    p.save
    p = Post.find('hello-world')
    p.body = "Once upon the times...."
    p.save
    p.update(draft: false)
    Post.bucket.get('hello-world')  #=> {"title"=>"Hello world", "draft"=>false,
                                    #    "body"=>"Once upon the times...."}
```

You can also let the library generate the unique identifier for you:

```ruby
    p = Post.create(title: 'How to generate ID',
                    body: 'Open up the editor...')
    p.id        #=> "post-abcDE34"
```

You can define connection options on per model basis:

```ruby
    class Post < CouchbaseOrm::Base
      attribute :title, type: String
      attribute :body,  type: String
      attribute :draft, type: Boolean

      connect bucket: 'blog', password: ENV['BLOG_BUCKET_PASSWORD']
    end
```

## Validations

There are all methods from ActiveModel::Validations accessible in
context of rails application. You can also enforce types using ruby
[conversion methods](http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/)

```ruby
    class Comment < Couchbase::Model
      attribute :author, :body, type: String

      validates_presence_of :author, :body
    end
```

## Views (aka Map/Reduce indexes)

Views are defined in the model and typically just emit an attribute that
can then be used for filtering results or ordering.

```ruby
    class Comment < CouchbaseOrm::Base
      attribute :author, :body, type: String
      view :all # => emits :id and will return all comments
      view :by_author, emit_key: :author

      # Generates two functions:
      # * the by_author view above
      # * def find_by_author(author); end
      index_view :author

      # You can make compound keys by passing an array to :emit_key
      # this allow to query by read/unread comments
      view :by_read, emit_key: [:user_id, :read]
      # this allow to query by view_count
      view :by_view_count, emit_key: [:user_id, :view_count]

      validates_presence_of :author, :body
    end
```

You can use `Comment.find_by_author('name')` to obtain all the comments by
a particular author. The same thing, using the view directly would be:
`Comment.by_author(key: 'name')`

When using a compound key, the usage is the same, you just give the full key :

```ruby
   Comment.by_read(key: '["'+user_id+'",false]') # gives all unread comments for one particular user

   # or even a range !

   Comment.by_view_count(startkey: '["'+user_id+'",10]', endkey: '["'+user_id+'",20]') # gives all comments that have been seen more than 10 times but less than 20
```

Check this couchbase help page to learn more on what's possible with compound keys : https://developer.couchbase.com/documentation/server/3.x/admin/Views/views-translateSQL.html

Ex : Compound keys allows to decide the order of the results, and you can reverse it by passing `descending: true`

## N1ql

Like views, it's possible to use N1QL to process some requests used for filtering results or ordering.

```ruby
    class Comment < CouchbaseOrm::Base
      attribute :author, :body, type: String
      n1ql :all # => emits :id and will return all comments
      n1ql :by_author, emit_key: :author

      # Generates two functions:
      # * the by_author view above
      # * def find_by_author(author); end
      index_n1ql :author

      # You can make compound keys by passing an array to :emit_key
      # this allow to query by read/unread comments
      n1ql :by_read, emit_key: [:user_id, :read]
      # this allow to query by view_count
      n1ql :by_view_count, emit_key: [:user_id, :view_count]

      validates_presence_of :author, :body
    end
```

Whatever the record, it's possible to execute a N1QL request with:

```ruby
Comment.bucket.n1ql.select('RAW meta(ui).id').from('bucket').where('author="my_value"').order_by('view_count DESC').results
```

## Associations and Indexes

There are common active record helpers available for use `belongs_to` and `has_many`

```ruby
    class Comment < CouchbaseOrm::Base
        belongs_to :author
    end

    class Author < CouchbaseOrm::Base
        has_many :comments, dependent: :destroy

        # You can ensure an attribute is unique for this model
        attribute :email, type: String
        ensure_unique :email
    end
```

By default, `has_many` uses a view for association, but you can define a `type` option to specify an association using N1QL instead:

```ruby
    class Comment < CouchbaseOrm::Base
        belongs_to :author
    end

    class Author < CouchbaseOrm::Base
        has_many :comments, type: :n1ql, dependent: :destroy
    end
```


## Performance Comparison with Couchbase-Ruby-Model

Basically we migrated an application from [Couchbase Ruby Model](https://github.com/couchbase/couchbase-ruby-model)
to [Couchbase-ORM](https://github.com/acaprojects/couchbase-orm) (this project)

* Rails 5 production
* Puma as the webserver
* Running on a 2015 Macbook Pro
* Performance test: `siege -c250 -r10  http://localhost:3000/auth/authority`

The request above pulls the same database document each time and returns it. A simple O(1) operation.

| Stat | Couchbase Ruby Model | Couchbase-ORM |
| :--- | :---                 |   :---        |
|Transactions|2500 hits|2500 hits|
|Elapsed time|12.24 secs|6.82 secs|
|Response time|0.88 secs|0.34 secs|
|Transaction rate|204.25 trans/sec|366.57 trans/sec|
|Request Code|[ruby-model-app](https://github.com/QuayPay/coauth/blob/95bbf5e5c3b3340e5af2da494b90c91c5e3d6eaa/app/controllers/auth/authorities_controller.rb#L6)|[couch-orm-app](https://github.com/QuayPay/coauth/blob/87f6fdeaab784ba252a5d38bbcf9e6b0477bb504/app/controllers/auth/authorities_controller.rb#L8)|
