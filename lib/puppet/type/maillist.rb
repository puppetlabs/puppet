module Puppet
  Type.newtype(:maillist) do
    @doc = "Manage email lists.  This resource type can only create
      and remove lists; it cannot currently reconfigure them."

    ensurable do
      defaultvalues

      newvalue(:purged) do
        provider.purge
      end

      def change_to_s(current_value, newvalue)
        return _("Purged %{resource}") % { resource: resource } if newvalue == :purged
        super
      end

      def insync?(is)
        return true if is == :absent && should == :purged
        super
      end
    end

    newparam(:name, :namevar => true) do
      desc "The name of the email list."
    end

    newparam(:description) do
      desc "The description of the mailing list."
    end

    newparam(:password) do
      desc "The admin password."
    end

    newparam(:webserver) do
      desc "The name of the host providing web archives and the administrative interface."
    end

    newparam(:mailserver) do
      desc "The name of the host handling email for the list."
    end

    newparam(:admin) do
      desc "The email address of the administrator."
    end

    def generate
      if provider.respond_to?(:aliases)
        should = self.should(:ensure) || :present
        if should == :purged
          should = :absent
        end
        atype = Puppet::Type.type(:mailalias)

        provider.aliases.
          reject  { |name,recipient| catalog.resource(:mailalias, name) }.
          collect { |name,recipient| atype.new(:name => name, :recipient => recipient, :ensure => should) }
      end
    end
  end
end
