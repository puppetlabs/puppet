require 'puppet/provider/nameservice/objectadd'

class Puppet::Provider::NameService
class PW < ObjectAdd
    def deletecmd
        [command(:pw), "#{@resource.class.name.to_s}del", @resource[:name]]
    end

    def modifycmd(param, value)
        cmd = [
            command(:pw),
            "#{@resource.class.name.to_s}mod",
            @resource[:name],
            flag(param),
            value
        ]
        return cmd
    end
end
end

