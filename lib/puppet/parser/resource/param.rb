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

        if l = self.line
            pn.line = Integer(l)
        end

        exists = {}
        pn.param_values.each { |pv| exists[pv.value] = pv }
        values.each do |value|
            unless pn.param_values.find_by_value(value)
                pn.param_values.build(:value => value)
            end
            # Mark that this is still valid.
            if exists.include?(value)
                exists.delete(value)
            end
        end

        # And remove any existing values that are not in the current value list.
        unless exists.empty?
            # We have to save the current state else the deletion somehow deletes
            # our new values.
            pn.save
            exists.each do |value, obj|
                pn.param_values.delete(obj)
            end
        end

        return pn
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
