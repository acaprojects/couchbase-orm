# encoding: utf-8

require 'rails/generators/couchbase_orm_generator'

module CouchbaseOrm
    module Generators
        class ConfigGenerator < Rails::Generators::Base
            desc 'Creates a Couchbase configuration file at config/couchbase.yml'
            argument :bucket_name, type: :string, optional: true
            argument :username, type: :string, optional: true
            argument :password, type: :string, optional: true

            def self.source_root
                @_couchbase_source_root ||= File.expand_path('../templates', __FILE__)
            end

            def app_name
                Rails::Application.subclasses.first.parent.to_s.underscore
            end

            def create_config_file
                template 'couchbase.yml', File.join('config', 'couchbase.yml')
            end

        end
    end
end
