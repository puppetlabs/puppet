# The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
    attr_accessor :name, :value, :source, :line, :file
    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::MethodHelper

    def initialize(hash)
        set_options(hash)
        requiredopts(:name, :value, :source)
        @name = symbolize(@name)
    end

    def inspect
        "#<#{self.class} @name => #{self.name}, @value => #{self.value}, @source => #{self.source.type}>"
    end

    # Store this parameter in a Rails db.
    def to_rails(res)
        values = value.is_a?(Array) ? value : [value]

        unless pn = res.param_names.find_by_name(self.name.to_s)
            # We're creating it anew.
            pn = res.param_names.build(:name => self.name.to_s)
        end
        
        value_objects = []

        if l = self.line
            pn.line = Integer(l)
        end

        pn.collection_merge(:param_values, values) do |value|
            unless pv = pn.param_values.find_by_value(value)
                pv = pn.param_values.build(:value => value)
            end
            pv
        end

        return pn
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
