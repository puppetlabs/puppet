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
        [:name, :value, :line, :file].each do |var|
            args[var] = self.send(var)
        end
        args[:name] = args[:name].to_s
        if obj = resource.rails_parameters.find_by_name(self.name)
            # We exist
            args.each do |p, v|
                obj[p] = v
            end
        else
            # Else create it anew
            obj = resource.rails_parameters.build(args)
        end

        return obj
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
