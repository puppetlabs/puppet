#
# Manage a router abstraction


module Puppet
  Type.newtype(:router) do
    @doc = "Manages connected router."

    newparam(:url) do
      desc <<-EOT
        An SSH or telnet URL at which to access the router, in the form
        `ssh://user:pass:enable@host/` or `telnet://user:pass:enable@host/`.
      EOT
      isnamevar
    end
  end
end
