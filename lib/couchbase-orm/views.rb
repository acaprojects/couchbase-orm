# frozen_string_literal: true, encoding: ASCII-8BIT

require 'active_model'

module CouchbaseOrm
    module Views
        extend ActiveSupport::Concern


        module ClassMethods
            # Defines a view for the model
            #
            # @param [Symbol, String, Array] names names of the views
            # @param [Hash] options options passed to the {Couchbase::View}
            #
            # @example Define some views for a model
            #  class Post < CouchbaseOrm::Base
            #    view :all
            #    view :by_rating, emit_key: :rating
            #  end
            #
            #  Post.by_rating.stream do |response|
            #    # ...
            #  end
            def view(name, map: nil, emit_key: nil, reduce: nil, **options)
                raise "unknown emit_key attribute for view :#{name}, emit_key: :#{emit_key}" if emit_key && @attributes[emit_key].nil?

                options = ViewDefaults.merge(options)

                method_opts = {}
                method_opts[:map]    = map    if map
                method_opts[:reduce] = reduce if reduce

                unless method_opts.has_key? :map
                    emit_key = emit_key || :id

                    if emit_key != :id && self.attributes[emit_key][:type].to_s == 'Array'
                        method_opts[:map] = <<-EMAP
function(doc) {
    var i;
    if (doc.type === "{{design_document}}") {
        for (i = 0; i < doc.#{emit_key}.length; i += 1) {
            emit(doc.#{emit_key}[i], null);
        }
    }
}
EMAP
                    else
                        method_opts[:map] = <<-EMAP
function(doc) {
    if (doc.type === "{{design_document}}") {
        emit(doc.#{emit_key}, null);
    }
}
EMAP
                    end
                end

                @views ||= {}

                name = name.to_sym
                @views[name] = method_opts

                singleton_class.__send__(:define_method, name) do |**opts, &result_modifier|
                    opts = options.merge(opts)

                    if result_modifier
                        opts[:include_docs] = true
                        bucket.view(@design_document, name, **opts, &result_modifier)
                    elsif opts[:include_docs]
                        bucket.view(@design_document, name, **opts) { |row|
                            self.new(row)
                        }
                    else
                        bucket.view(@design_document, name, **opts)
                    end
                end
            end
            ViewDefaults = {include_docs: true}

            # add a view and lookup method to the model for finding all records
            # using a value in the supplied attr.
            def index_view(attr, validate: true, find_method: nil, view_method: nil)
                view_method ||= "by_#{attr}"
                find_method ||= "find_#{view_method}"

                validates(attr, presence: true) if validate
                view view_method, emit_key: attr

                instance_eval "
                    def self.#{find_method}(#{attr})
                        #{view_method}(key: #{attr})
                    end
                "
            end

            def ensure_design_document!
                return false unless @views && !@views.empty?
                existing = {}
                update_required = false

                # Grab the existing view details
                ddoc = bucket.design_docs[@design_document]
                existing = ddoc.view_config if ddoc

                views_actual = {}
                # Fill in the design documents
                @views.each do |name, document|
                    doc = document.dup
                    views_actual[name] = doc
                    doc[:map] = doc[:map].gsub('{{design_document}}', @design_document) if doc[:map]
                    doc[:reduce] = doc[:reduce].gsub('{{design_document}}', @design_document) if doc[:reduce]
                end

                # Check there are no changes we need to apply
                views_actual.each do |name, desired|
                    check = existing[name]
                    if check
                        cmap = (check[:map] || '').gsub(/\s+/, '')
                        creduce = (check[:reduce] || '').gsub(/\s+/, '')
                        dmap = (desired[:map] || '').gsub(/\s+/, '')
                        dreduce = (desired[:reduce] || '').gsub(/\s+/, '')

                        unless cmap == dmap && creduce == dreduce
                            update_required = true
                            break
                        end
                    else
                        update_required = true
                        break
                    end
                end

                # Updated the design document
                if update_required
                    bucket.save_design_doc({
                        views: views_actual
                    }, @design_document)

                    puts "Couchbase views updated for #{self.name}, design doc: #{@design_document}"
                    true
                else
                    false
                end
            end
        end
    end
end
