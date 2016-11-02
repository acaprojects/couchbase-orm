module CouchbaseOrm
    module HasMany
        private

        # generate a method which returns an instance of RelationSet scoped to the
        # current model instance. RelationSet includes Enumerable, and caches the
        # list of associated records after the first request. lookups can be made
        # directly on a model, or through a join model - different methods are used
        # to retrieve associated records in each case. when using has_many directly
        # on a join model, extra methods such as create! and exists? become
        # available. these are helper methods that improve lookup speed or make
        # creating associations easier. all features rely on special methods being
        # available on target models. Join and IndexBy provide these methods.
        
        # e.g in Playlist
        # has_many :entries
        # playlist.entries.each ...
        # => Entry.find_by_playlist_id(id)

        # has_many :articles, through: :entries
        # playlist.articles.each ...
        # => Entry.articles_by_playlist_id(id)
        # playlist.articles.exists?('art-B0')
        # => !Entry.find_by_playlist_id_and_article_id(id, 'art-B0').nil?

        class RelationSet
            include Enumerable

            def initialize(instance, model, options)
                @id = instance.id

                # target is the model methods are run on. should always be a join
                # model this may not be the same model type that's returned by each -
                # :through will mean records of type model will be returned after
                # calling methods on the model specified by target
                @target_name = options[:through] || model

                # eval target ("User" => User object)
                @target = @target_name.to_s.singularize.camelcase.constantize

                # name of the current model, used in the find method and attrs
                @class_name = instance.class.name.underscore

                # if model == target (no :through), use find_by to retrieve instances
                # of the model. otherwise assume the :through model is extended by
                # Join and use the methods it exposes to retrieve instances of model.
                # has_many on a join model enables extra methods that operate on the
                # join records, such as find and create!
                if options[:through]
                    @each_method = "#{model.to_s.underscore.pluralize}_by_#{@class_name}_id"
                else
                    @each_method = "find_by_#{@class_name}_id"
                    join_models = @target.instance_variable_get('@join_models')
                    
                    if join_models
                        remainder = join_models - [instance.class.name.underscore]
                        raise 'Associated join model doesn\'t join the current model' unless remainder.length == 1
                        @other_name = remainder.first
                        @find_method = "find_by_#{@class_name}_id_and_#{@other_name}_id"
                    end
                end
            end

            # let enumerable handle count, each, empty? etc. view is cached between
            # enumerable calls, use reload to invalidate it.
            def each(&block)
                @view ||= @target.send(@each_method, @id)
                @view.each(&block)
            end

            # if the set of related records changes during an object's lifetime,
            # call reload so the new records can be loaded
            def reload
                @view = nil
            end

            def empty?
                self.count == 0
            end

            # create! only works on has_many associations that don't run through
            # a join model (e.g has_many :memberships, vs has_many :users,
            # through: :memberships). creates a new join record only if an existing
            # record doesn't already exist. if attrs are provided, an existing
            # record can be updated however. e.g group.memberships.create!(user_id)
            # followed by group.memberships.create!(user_id, admin: true) will result
            # in the join record being updated by the second call, or created if it
            # didn't previously exist. by default, force = false makes create! treat
            # the association like a set - if a join record exists for other_id a
            # new record won't be created. set force = true to make create! treat
            # the association like a list, and create a new record on each call.
            def _create(other_id, attrs, force)
                raise 'Cannot call create! on a non-join model' unless @find_method
                join = force ? nil : find(other_id)
                return join if (join && attrs.empty?)

                # create! short circuits if a join record already exists, and no
                # attrs are provided. otherwise a new or existing join model is
                # updated with attrs before being saved
                join ||= @target.new
                join.assign_attributes(attrs.merge!({
                    "#{@class_name}_id" => @id,
                    "#{@other_name}_id" => other_id
                }))
                join
            end

            def create(other_id, attrs = {}, force = false)
                _create(other_id, attrs, force).tap do |record|
                    record.save
                end
            end

            def create!(other_id, attrs = {}, force = false)
                _create(other_id, attrs, force).tap do |record|
                    record.save!
                end
            end

            def find(other_id)
                raise 'Cannot call find on a non-join model' unless @find_method
                return nil unless other_id.present?
                @target.send(@find_method, @id, other_id)
            end

            def delete!(other_id)
                raise 'Cannot call delete! on a non-join model' unless @find_method
                find(other_id).try(:delete)
            end

            def exists?(other_id)
                raise 'Cannot call exists? on a non-join model' unless @find_method
                return false unless other_id.present?
                !find(other_id).nil?
            end
        end


        def has_many(model, options = {})
            relset_varname = "@#{model}_rel_set"

            define_method(model) do
                relset = self.instance_variable_get(relset_varname)
                return relset if relset
                self.instance_variable_set(relset_varname, RelationSet.new(self, model, options))
            end
        end
    end
end
