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
    def to_rails(res, pn = nil)
        values = value.is_a?(Array) ? value : [value]

        values = values.collect { |v| v.to_s }

        unless pn
            # We're creating it anew.
            pn = res.param_names.build(:name => self.name.to_s)
        end
        
        value_objects = []

        if l = self.line
            pn.line = Integer(l)
        end

        oldvals = []

        if pv = pn.param_values
            newvals = pv.each do |val|
                oldvals << val.value
            end
        end

        if oldvals != values
            #pn.param_values = values.collect { |v| pn.param_values.build(:value => v.to_s) }
            objects = values.collect do |v|
                pn.param_values.build(:value => v.to_s)
            end
            pn.param_values = objects
        end

        return pn
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
