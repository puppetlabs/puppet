Puppet::Type.newtype(:mcx) do

  @doc = "MCX object management using DirectoryService on OS X.

The default provider of this type merely manages the XML plist as
reported by the `dscl -mcxexport` command.  This is similar to the
content property of the file type in Puppet.

The recommended method of using this type is to use Work Group Manager
to manage users and groups on the local computer, record the resulting
puppet manifest using the command `puppet resource mcx`, then deploy it
to other machines.

**Autorequires:** If Puppet is managing the user, group, or computer that these
MCX settings refer to, the MCX resource will autorequire that user, group, or computer.
"
  feature :manages_content, \
    "The provider can manage MCXSettings as a string.",
    :methods => [:content, :content=]

  ensurable do
    desc "Create or remove the MCX setting."

    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end

  end

  newparam(:name) do
    desc "The name of the resource being managed.
    The default naming convention follows Directory Service paths:

        /Computers/localhost
        /Groups/admin
        /Users/localadmin

    The `ds_type` and `ds_name` type parameters are not necessary if the
    default naming convention is followed."
    isnamevar
  end

  newparam(:ds_type) do

    desc "The DirectoryService type this MCX setting attaches to."

    newvalues(:user, :group, :computer, :computerlist)

  end

  newparam(:ds_name) do
    desc "The name to attach the MCX Setting to. (For example, `localhost`
    when `ds_type => computer`.) This setting is not required, as it can be
    automatically discovered when the resource name is parseable.  (For
    example, in `/Groups/admin`, `group` will be used as the dstype.)"
  end

  newproperty(:content, :required_features => :manages_content) do
    desc "The XML Plist used as the value of MCXSettings in DirectoryService.
    This is the standard output from the system command:

        dscl localhost -mcxexport /Local/Default/<ds_type>/ds_name

    Note that `ds_type` is capitalized and plural in the dscl command."
  end

  # JJM Yes, this is not DRY at all.  Because of the code blocks
  # autorequire must be done this way.  I think.

  def setup_autorequire(type)
    # value returns a Symbol
    ds_type = value(:ds_type)
    ds_name = value(:ds_name)
    if ds_type == type
      rval = [ ds_name.to_s ]
    else
      rval = [ ]
    end
    rval
  end

  autorequire(:user) do
    setup_autorequire(:user)
  end

  autorequire(:group) do
    setup_autorequire(:group)
  end

  autorequire(:computer) do
    setup_autorequire(:computer)
  end

end
