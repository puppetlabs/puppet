Puppet::Type.newtype(:computer) do

  @doc = "Computer object management using DirectoryService
    on OS X.

    Note that these are distinctly different kinds of objects to 'hosts',
    as they require a MAC address and can have all sorts of policy attached to
    them.

    This provider only manages Computer objects in the local directory service
    domain, not in remote directories.

    If you wish to manage `/etc/hosts` file on Mac OS X, then simply use the host
    type as per other platforms.

    This type primarily exists to create localhost Computer objects that MCX
    policy can then be attached to.

    **Autorequires:** If Puppet is managing the plist file representing a
    Computer object (located at `/var/db/dslocal/nodes/Default/computers/{name}.plist`),
    the Computer resource will autorequire it."

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
    desc "Control the existences of this computer record. Set this attribute to
      `present` to ensure the computer record exists.  Set it to `absent`
      to delete any computer records with this name"
    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.delete
    end
  end

  newparam(:name) do
    desc "The authoritative 'short' name of the computer record."
    isnamevar
  end

  newparam(:realname) do
    desc "The 'long' name of the computer record."
  end

  newproperty(:en_address) do
    desc "The MAC address of the primary network interface. Must match en0."
  end

  newproperty(:ip_address) do
    desc "The IP Address of the Computer object."
  end

end
