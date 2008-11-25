Puppet::Type.newtype(:computer) do
    
    @doc = "Computer object management using DirectoryService on OS X.
    
    Note that these are distinctly different kinds of objects to 'hosts',
    as they require a MAC address and can have all sorts of policy attached to
    them.
    
    This provider only manages Computer objects in the local directory service
    domain, not in remote directories.
    
    If you wish to manage /etc/hosts on Mac OS X, then simply use the host
    type as per other platforms.
    
    This type primarily exists to create localhost Computer objects that MCX
    policy can then be attached to."
    
    # ensurable
    
    # We autorequire the computer object in case it is being managed at the
    # file level by Puppet.
    
    autorequire(:file) do
        if self[:name]
            "/var/db/dslocal/nodes/Default/computers/#{self[:name]}.plist"
        else
            nil
        end
    end
    
    newproperty(:ensure, :parent => Puppet::Property::Ensure) do
        newvalue(:present) do
            provider.create
        end

        newvalue(:absent) do
            Puppet.notice "prop ensure = absent"
            provider.delete
        end
    end
    
    newparam(:name) do
        desc "The "
        isnamevar
    end
    
    newparam(:realname) do
        desc "realname"
    end
        
    newproperty(:en_address) do
        desc "The MAC address of the primary network interface. Must match en0."
    end
    
    newproperty(:ip_address) do
        desc "The IP Address of the Computer object."
    end
    
end