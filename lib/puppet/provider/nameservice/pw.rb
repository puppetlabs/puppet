# frozen_string_literal: true

require_relative '../../../puppet/provider/nameservice/objectadd'

class Puppet::Provider::NameService
  class PW < ObjectAdd
    def deletecmd
      [command(:pw), "#{@resource.class.name}del", @resource[:name]]
    end

    def modifycmd(param, value)
      [
        command(:pw),
        "#{@resource.class.name}mod",
        @resource[:name],
        flag(param),
        munge(param, value)
      ]
    end
  end
end
