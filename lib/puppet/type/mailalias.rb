module Puppet
  Type.newtype(:mailalias) do
    @doc = "Creates an email alias in the local alias database."

    ensurable

    newparam(:name, :namevar => true) do
      desc "The alias name."
    end

    newproperty(:recipient, :array_matching => :all) do
      desc "Where email should be sent.  Multiple values
        should be specified as an array.  The file and the
        recipient entries are mutually exclusive."
    end

    newproperty(:file) do
      desc "A file containing the alias's contents.  The file and the
        recipient entries are mutually exclusive."

      validate do |value|
	unless Puppet::Util.absolute_path?(value)
	  fail Puppet::Error, _("File paths must be fully qualified, not '%{value}'") % { value: value }
	end
      end
    end

    newproperty(:target) do
      desc "The file in which to store the aliases.  Only used by
        those providers that write to disk."

      defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
          @resource.class.defaultprovider.default_target
        else
          nil
        end
      }
    end

    validate do
      if self[:recipient] && self[:file]
	self.fail _("You cannot specify both a recipient and a file")
      end
    end
  end
end
