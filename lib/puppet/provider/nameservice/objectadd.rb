require 'puppet/provider/nameservice'

class Puppet::Provider::NameService
class ObjectAdd < Puppet::Provider::NameService
    # Does the object already exist?
    def self.exists?(obj)
        if obj.getinfo(true)
            return true
        else
            return false
        end
    end
    
    def deletecmd
        [command(:delete), @model[:name]]
    end

    # Determine the flag to pass to our command.
    def flag(name)
        name = name.intern if name.is_a? String
        self.class.option(name, :flag) || "-" + name.to_s[0,1]
    end

    def modifycmd(param, value)
        cmd = [command(:modify),
            flag(param),
            value]
        if @model[:allowdupe]  == :true
            cmd << "-o"
        end
        cmd << @model[:name]

        return cmd
    end

    def posixmethod(name)
        name = name.intern if name.is_a? String
        method = self.class.option(name, :method) || name

        return method
    end
end
end

# $Id$
