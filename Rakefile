require 'rubygems'
require 'rspec/core/rake_task'  # testing framework
require 'yard'                  # yard documentation

# By default we don't run network tests
task :default => :test

RSpec::Core::RakeTask.new(:spec)

desc 'Run all tests'
task :test => [:spec]

YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', '-', 'README.md']
end
