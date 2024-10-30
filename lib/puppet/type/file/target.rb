# frozen_string_literal: true

module Puppet
  Puppet::Type.type(:file).newproperty(:target) do
    desc "The target for creating a link.  Currently, symlinks are the
      only type supported. This attribute is mutually exclusive with `source`
      and `content`.

      Symlink targets can be relative, as well as absolute:

          # (Useful on Solaris)
          file { '/etc/inetd.conf':
            ensure => link,
            target => 'inet/inetd.conf',
          }

      Directories of symlinks can be served recursively by instead using the
      `source` attribute, setting `ensure` to `directory`, and setting the
      `links` attribute to `manage`."

    newvalue(:notlink) do
      # We do nothing if the value is absent
      return :nochange
    end

    # Anything else, basically
    newvalue(/./) do
      @resource[:ensure] = :link unless @resource.should(:ensure)

      # Only call mklink if ensure didn't call us in the first place.
      currentensure = @resource.property(:ensure).retrieve
      mklink if @resource.property(:ensure).safe_insync?(currentensure)
    end

    # Create our link.
    def mklink
      raise Puppet::Error, "Cannot symlink on this platform version" unless provider.feature?(:manages_symlinks)

      target = should

      # Clean up any existing objects.  The argument is just for logging,
      # it doesn't determine what's removed.
      @resource.remove_existing(target)

      raise Puppet::Error, "Could not remove existing file" if Puppet::FileSystem.exist?(@resource[:path])

      Puppet::Util::SUIDManager.asuser(@resource.asuser) do
        mode = @resource.should(:mode)
        if mode
          Puppet::Util.withumask(0o00) do
            Puppet::FileSystem.symlink(target, @resource[:path])
          end
        else
          Puppet::FileSystem.symlink(target, @resource[:path])
        end
      end

      @resource.send(:property_fix)

      :link_created
    end

    def exist?
      if resource[:links] == :manage
        # When managing links directly, test to see if the link itself
        # exists.
        Puppet::FileSystem.exist_nofollow?(@resource[:path])
      else
        # Otherwise, allow links to be followed.
        Puppet::FileSystem.exist?(@resource[:path])
      end
    end

    def insync?(currentvalue)
      if [:nochange, :notlink].include?(should) or @resource.recurse?
        true
      elsif !@resource.replace? and exist?
        true
      else
        super(currentvalue)
      end
    end

    def retrieve
      stat = @resource.stat
      if stat
        if stat.ftype == "link"
          Puppet::FileSystem.readlink(@resource[:path])
        else
          :notlink
        end
      else
        :absent
      end
    end
  end
end
