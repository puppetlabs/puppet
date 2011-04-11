#
# Manage a router abstraction
#

module Puppet
  newtype(:router) do
    @doc = "Manages connected router."

    newparam(:url) do
      desc "An URL to access the router of the form (ssh|telnet)://user:pass:enable@host/."
      isnamevar
    end
  end
end
