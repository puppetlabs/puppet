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
	#FIXME: re-add line/file support
        #[:name, :value, :line, :file].each do |var|
        [:name, :value ].each do |var|
            if val = self.send(var)
                args[var] = val
            end
        end
        args[:name] = args[:name].to_s
        if pname = resource.param_names.find_by_name(self.name)
            # We exist
            args.each do |p, v|
                pname.param_values.build(v)
            end
        else
            # Else create it anew
            obj = resource.param_names.build(:name => self.class)
        end

        return obj
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end

# $Id$
