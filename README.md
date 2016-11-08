# Couchbase ORM for Rails

## Rails integration

To generate config you can use `rails generate couchbase_orm:config`:

    $ rails generate couchbase_orm:config
    create  config/couchbase.yml

It will generate this `config/couchbase.yml` for you:

    common: &common
      hosts: localhost
      password:

    development:
      <<: *common
      bucket: default

    test:
      <<: *common
      bucket: app_name_test
      password: for_test_bucket

    # set these environment variables on your production server
    production:
      hosts: <%= ENV['COUCHBASE_HOST'] || ENV['COUCHBASE_HOSTS'] %>
      bucket: <%= ENV['COUCHBASE_BUCKET'] %>
      password: <%= ENV['COUCHBASE_PASSWORD'] %>


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

      validates_presence_of :author, :body
    end
```

You can use `Comment.find_by_author('name')` to obtain all the comments by
a particular author. The same thing, using the view directly would be:
`Comment.by_author(key: 'name')`

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


