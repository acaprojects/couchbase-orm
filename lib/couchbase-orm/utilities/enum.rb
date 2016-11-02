module CouchbaseOrm
    module Enum
        private

        def enum(options)
            # options contains an optional default value, and the name of the
            # enum, e.g enum visibility: %i(group org public), default: :group
            default = options.delete(:default)
            name = options.keys.first
            values = options[name]

            # values is assumed to be a list of symbols. each value is assigned an
            # integer, and this number is used for db storage. numbers start at 1.
            mapping = {}
            values.each_with_index do |value, i|
                mapping[value.to_sym] = i + 1
                mapping[i + 1] = value.to_sym
            end

            # VISIBILITY = {group: 0, 0: group ...}
            const_set(name.to_s.upcase, mapping)

            # lookup the default's integer value
            if default
                default_value = mapping[default]
                raise 'Unknown default value' unless default_value
            else
                default_value = 1
            end
            attribute name, default: default_value

            # keep the attribute's value within bounds
            before_save do |record|
                record[name] = record[name].to_i
                record[name] = (1..values.length).cover?(record[name]) ? record[name] : default_value
            end
        end
    end
end
