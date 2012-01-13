
module Puppet
  Puppet::Type.type(:file).ensurable do
    require 'etc'
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode

    desc <<-EOT
      Whether to create files that don't currently exist.
      Possible values are *absent*, *present*, *file*, and *directory*.
      Specifying `present` will match any form of file existence, and
      if the file is missing will create an empty file. Specifying
      `absent` will delete the file (and directory if `recurse => true`).

      Anything other than those values will create a symlink. In the interest
      of readability and clarity, you should use `ensure => link` and
      explicitly specify a target; however, if a `target` attribute isn't
      provided, the value of the `ensure` attribute will be used as the
      symlink target. The following two declarations are equivalent:

          # (Useful on Solaris)

          # Less maintainable:
          file { "/etc/inetd.conf":
            ensure => "/etc/inet/inetd.conf",
          }

          # More maintainable:
          file { "/etc/inetd.conf":
            ensure => link,
            target => "/etc/inet/inetd.conf",
          }
    EOT

    # Most 'ensure' properties have a default, but with files we, um, don't.
    nodefault

    newvalue(:absent) do
      File.unlink(@resource[:path])
    end

    aliasvalue(:false, :absent)

    newvalue(:file, :event => :file_created) do
      # Make sure we're not managing the content some other way
      if property = @resource.property(:content)
        property.sync
      else
        @resource.write(:ensure)
        mode = @resource.should(:mode)
      end
    end

    #aliasvalue(:present, :file)
    newvalue(:present, :event => :file_created) do
      # Make a file if they want something, but this will match almost
      # anything.
      set_file
    end

    newvalue(:directory, :event => :directory_created) do
      mode = @resource.should(:mode)
      parent = File.dirname(@resource[:path])
      unless FileTest.exists? parent
        raise Puppet::Error,
          "Cannot create #{@resource[:path]}; parent directory #{parent} does not exist"
      end
      if mode
        Puppet::Util.withumask(000) do
          Dir.mkdir(@resource[:path], symbolic_mode_to_int(mode, 755, true))
        end
      else
        Dir.mkdir(@resource[:path])
      end
      @resource.send(:property_fix)
      return :directory_created
    end


    newvalue(:link, :event => :link_created) do
      fail "Cannot create a symlink without a target" unless property = resource.property(:target)
      property.retrieve
      property.mklink
    end

    # Symlinks.
    newvalue(/./) do
      # This code never gets executed.  We need the regex to support
      # specifying it, but the work is done in the 'symlink' code block.
    end

    munge do |value|
      value = super(value)
      value,resource[:target] = :link,value unless value.is_a? Symbol
      resource[:links] = :manage if value == :link and resource[:links] != :follow
      value
    end

    def change_to_s(currentvalue, newvalue)
      return super unless newvalue.to_s == "file"

      return super unless property = @resource.property(:content)

      # We know that content is out of sync if we're here, because
      # it's essentially equivalent to 'ensure' in the transaction.
      if source = @resource.parameter(:source)
        should = source.checksum
      else
        should = property.should
      end
      if should == :absent
        is = property.retrieve
      else
        is = :absent
      end

      property.change_to_s(is, should)
    end

    # Check that we can actually create anything
    def check
      basedir = File.dirname(@resource[:path])

      if ! FileTest.exists?(basedir)
        raise Puppet::Error,
          "Can not create #{@resource.title}; parent directory does not exist"
      elsif ! FileTest.directory?(basedir)
        raise Puppet::Error,
          "Can not create #{@resource.title}; #{dirname} is not a directory"
      end
    end

    # We have to treat :present specially, because it works with any
    # type of file.
    def insync?(currentvalue)
      unless currentvalue == :absent or resource.replace?
        return true
      end

      if self.should == :present
        return !(currentvalue.nil? or currentvalue == :absent)
      else
        return super(currentvalue)
      end
    end

    def retrieve
      if stat = @resource.stat
        return stat.ftype.intern
      else
        if self.should == :false
          return :false
        else
          return :absent
        end
      end
    end

    def sync
      @resource.remove_existing(self.should)
      if self.should == :absent
        return :file_removed
      end

      event = super

      event
    end
  end
end

