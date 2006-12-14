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
    def store(resource)
        args = {}
        #[:name, :value, :line, :file].each do |var|
        [:name, :value].each do |var|
            args[var] = self.send(var)
        end
        args[:name] = args[:name].to_s
        args[:name].each do |name|
            pn = resource.param_names.find_or_create_by_name(name)
            args[:value].each do |value|
                pv = pn.param_values.find_or_create_by_value(value)
            end
        end
        obj = resource.param_names.find_by_name(args[:name], :include => :param_values)

        return obj
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
