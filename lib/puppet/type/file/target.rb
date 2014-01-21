module Puppet
  Puppet::Type.type(:file).newproperty(:target) do
    desc "The target for creating a link.  Currently, symlinks are the
      only type supported. This attribute is mutually exclusive with `source`
      and `content`.

      Symlink targets can be relative, as well as absolute:

          # (Useful on Solaris)
          file { \"/etc/inetd.conf\":
            making_sure => link,
            target => \"inet/inetd.conf\",
          }

      Directories of symlinks can be served recursively by instead using the
      `source` attribute, setting `making_sure` to `directory`, and setting the
      `links` attribute to `manage`."

    newvalue(:notlink) do
      # We do nothing if the value is absent
      return :nochange
    end

    # Anything else, basically
    newvalue(/./) do
      @resource[:making_sure] = :link if ! @resource.should(:making_sure)

      # Only call mklink if making_sure didn't call us in the first place.
      currentmaking_sure  = @resource.property(:making_sure).retrieve
      mklink if @resource.property(:making_sure).safe_insync?(currentmaking_sure)
    end

    # Create our link.
    def mklink
      raise Puppet::Error, "Cannot symlink on this platform version" if !provider.feature?(:manages_symlinks)

      target = self.should

      # Clean up any existing objects.  The argument is just for logging,
      # it doesn't determine what's removed.
      @resource.remove_existing(target)

      raise Puppet::Error, "Could not remove existing file" if Puppet::FileSystem.exist?(@resource[:path])

      Dir.chdir(File.dirname(@resource[:path])) do
        Puppet::Util::SUIDManager.asuser(@resource.asuser) do
          mode = @resource.should(:mode)
          if mode
            Puppet::Util.withumask(000) do
              Puppet::FileSystem.symlink(target, @resource[:path])
            end
          else
            Puppet::FileSystem.symlink(target, @resource[:path])
          end
        end

        @resource.send(:property_fix)

        :link_created
      end
    end

    def insync?(currentvalue)
      if [:nochange, :notlink].include?(self.should) or @resource.recurse?
        return true
      elsif ! @resource.replace? and Puppet::FileSystem.exist?(@resource[:path])
        return true
      else
        return super(currentvalue)
      end
    end


    def retrieve
      if stat = @resource.stat
        if stat.ftype == "link"
          return Puppet::FileSystem.readlink(@resource[:path])
        else
          return :notlink
        end
      else
        return :absent
      end
    end
  end
end

