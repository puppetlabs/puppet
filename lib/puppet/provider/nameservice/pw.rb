require 'puppet/provider/nameservice/objectadd'

class Puppet::Provider::NameService
  class PW < ObjectAdd
    def deletecmd
<<<<<<< HEAD
      [command(:pw), "#{@resource.class.name.to_s}del", @resource[:name]]
=======
      [command(:pw), "#{@resource.class.name}del", @resource[:name]]
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
    end

    def modifycmd(param, value)
      cmd = [
          command(:pw),
<<<<<<< HEAD
          "#{@resource.class.name.to_s}mod",
=======
          "#{@resource.class.name}mod",
>>>>>>> 0f9c4b5e8b7f56ba94587b04dc6702a811c0a6b7
          @resource[:name],
          flag(param),
          munge(param, value)
      ]
      cmd
    end
  end
end

