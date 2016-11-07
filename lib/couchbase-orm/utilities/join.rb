module CouchbaseOrm
    module Join
        private

        # join adds methods for retrieving the join model by user or group, and
        # methods for retrieving either model through the join model (e.g all
        # users who are in a group). model_a and model_b must be strings or symbols
        # and are assumed to be singularised, underscored versions of model names
        def join(model_a, model_b, options={})
            # store the join model names for use by has_many associations
            @join_models = [model_a.to_s, model_b.to_s]

            # join :user, :group => design_document :ugj
            doc_name = options[:design_document] || "#{model_a.to_s[0]}#{model_b.to_s[0]}j".to_sym
            design_document doc_name

            # a => b
            add_single_sided_features(model_a)
            add_joint_lookups(model_a, model_b)

            # b => a
            add_single_sided_features(model_b)
            add_joint_lookups(model_b, model_a, true)

            # use Index to allow lookups of joint records more efficiently than
            # with a view or search
            index ["#{model_a}_id".to_sym, "#{model_b}_id".to_sym], :join
        end

        def add_single_sided_features(model)
            # belongs_to :group
            belongs_to model

            # view :by_group_id
            view "by_#{model}_id"

            # find_by_group_id
            instance_eval "
                def self.find_by_#{model}_id(#{model}_id)
                    by_#{model}_id(key: #{model}_id)
                end
            "
        end

        def add_joint_lookups(model_a, model_b, reverse = false)
            # find_by_user_id_and_group_id
            instance_eval "
                def self.find_by_#{model_a}_id_and_#{model_b}_id(#{model_a}_id, #{model_b}_id)
                    self.find_by_join([#{reverse ? model_b : model_a}_id, #{reverse ? model_a : model_b}_id])
                end
            "

            # user_ids_by_group_id
            instance_eval "
                def self.#{model_a}_ids_by_#{model_b}_id(#{model_b}_id)
                    self.find_by_#{model_b}_id(#{model_b}_id).map(&:#{model_a}_id)
                end
            "

            # users_by_group_id
            instance_eval "
                def self.#{model_a.to_s.pluralize}_by_#{model_b}_id(#{model_b}_id)
                    self.find_by_#{model_b}_id(#{model_b}_id).map(&:#{model_a})
                end
            "
        end
    end
end
