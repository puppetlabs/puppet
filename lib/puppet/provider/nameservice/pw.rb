require 'puppet/provider/nameservice/objectadd'

class Puppet::Provider::NameService
class PW < ObjectAdd
    def deletecmd
        "#{command(:pw)} #{@model.class.name.to_s}del %s" % @model[:name]
    end

    def modifycmd(param, value)
        cmd = [
            command(:pw),
            "#{@model.class.name.to_s}mod",
            @model[:name],
            flag(param),
            "'%s'" % value
        ]
        return cmd.join(" ")
    end
end
end

# $Id$
