class Puppet::Rails::ParamValue < ActiveRecord::Base
    belongs_to :param_name
    belongs_to :resource

    def value
        val = self[:value]
        if val =~ /^--- \!/
            YAML.load(val)
        else
            val
        end
    end

    # I could not find a cleaner way to handle making sure that resource references
    # were consistently serialized and deserialized.
    def value=(val)
        if val.is_a?(Puppet::Parser::Resource::Reference)
            self[:value] = YAML.dump(val)
        else
            self[:value] = val
        end
    end

    def to_label
      "#{self.param_name.name}"
    end  
end

