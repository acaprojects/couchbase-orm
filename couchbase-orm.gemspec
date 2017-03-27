require File.expand_path("../lib/couchbase-orm/version", __FILE__)

Gem::Specification.new do |gem|
    gem.name          = "couchbase-orm"
    gem.version       = CouchbaseOrm::VERSION
    gem.license       = 'MIT'
    gem.authors       = ["Stephen von Takach"]
    gem.email         = ["steve@cotag.me"]
    gem.homepage      = "https://github.com/cotag/couchbase-orm"
    gem.summary       = "Couchbase ORM for Rails"
    gem.description   = "A Couchbase ORM for Rails"

    gem.required_ruby_version = '>= 2.1.0'
    gem.require_paths = ["lib"]

    gem.add_runtime_dependency     'libcouchbase', '~> 0.1'
    gem.add_runtime_dependency     'activemodel',  '~> 5.0'
    gem.add_runtime_dependency     'radix',        '~> 2.2' # converting numbers to and from any base

    gem.add_development_dependency 'rake',         '~> 11.2'
    gem.add_development_dependency 'rspec',        '~> 3.5'
    gem.add_development_dependency 'yard',         '~> 0.9'
    gem.add_development_dependency 'minitest',     '~> 5.9'

    gem.files         = `git ls-files`.split("\n")
    gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
end
