Puppet::Type.newtype(:a2mod) do
    @doc = "Manage Apache 2 modules"

    making_surable

    newparam(:name) do
       desc "The name of the module to be managed"

       isnamevar

    end
end
