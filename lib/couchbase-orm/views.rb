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

                yield method_opts if block_given?
                unless method_opts.has_key? :map
                    emit_key = emit_key || :id
                    method_opts[:map] = "function(doc) {\n\tif (doc.type === \"#{@design_document}\") {\n\t\temit(doc.#{emit_key}, null);\n\t}\n}"
                end

                @views ||= {}

                name = name.to_sym
                @views[name] = method_opts

                singleton_class.send(:define_method, name) do |**opts|
                    opts = options.merge(opts)
                    include_docs = opts[:include_docs]

                    bucket.view(@design_document, name, **opts) { |row|
                        if include_docs
                            self.new(row)
                        else
                            row
                        end
                    }
                end
            end
            ViewDefaults = {include_docs: true}

            def ensure_design_document!
                return unless @views && !@views.empty?
                existing = {}
                update_required = false

                # Grab the existing view details
                ddoc = bucket.design_docs[@design_document]
                existing = ddoc.view_config if ddoc

                # Check there are no changes we need to apply
                (@views || {}).each do |name, desired|
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
                        views: @views
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
