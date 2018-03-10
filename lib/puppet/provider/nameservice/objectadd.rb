require 'puppet/provider/nameservice'

class Puppet::Provider::NameService
  class ObjectAdd < Puppet::Provider::NameService
    def deletecmd
      [command(:delete), @resource[:name]]
    end

    # Determine the flag to pass to our command.
    def flag(name)
      name = name.intern if name.is_a? String
      self.class.option(name, :flag) || "-" + name.to_s[0, 1]
    end

    def posixmethod(name)
      name   = name.intern if name.is_a? String
      method = self.class.option(name, :method) || name

      method
    end
  end
end
