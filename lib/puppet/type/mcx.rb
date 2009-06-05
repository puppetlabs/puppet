#--
# Copyright (C) 2008 Jeffrey J McCune.

# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software
# Foundation; either version 2 of the License, or any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# Author: Jeff McCune <mccune.jeff@gmail.com>

Puppet::Type.newtype(:mcx) do

    @doc = "MCX object management using DirectoryService on OS X.

Original Author: Jeff McCune <mccune.jeff@gmail.com>

The default provider of this type merely manages the XML plist as
reported by the dscl -mcxexport command.  This is similar to the
content property of the file type in Puppet.

The recommended method of using this type is to use Work Group Manager
to manage users and groups on the local computer, record the resulting
puppet manifest using the command 'ralsh mcx' then deploying this
to other machines.
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
        The default naming convention follows Directory Service paths::

          /Computers/localhost
          /Groups/admin
          /Users/localadmin

        The ds_type and ds_name type parameters are not necessary if the
        default naming convention is followed."
        isnamevar
    end

    newparam(:ds_type) do

        desc "The DirectoryService type this MCX setting attaches to."

        newvalues(:user, :group, :computer, :computerlist)

    end

    newparam(:ds_name) do
        desc "The name to attach the MCX Setting to.
        e.g. 'localhost' when ds_type => computer. This setting is not
        required, as it may be parsed so long as the resource name is
        parseable.  e.g. /Groups/admin where 'group' is the dstype."
    end

    newproperty(:content, :required_features => :manages_content) do
        desc "The XML Plist.  The value of MCXSettings in DirectoryService.
        This is the standard output from the system command:
        dscl localhost -mcxexport /Local/Default/<ds_type>/<ds_name>
        Note that ds_type is capitalized and plural in the dscl command."
    end

    # JJM Yes, this is not DRY at all.  Because of the code blocks
    # autorequire must be done this way.  I think.

    def setup_autorequire(type)
        # value returns a Symbol
        name = value(:name)
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
