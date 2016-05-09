
module Puppet
  Puppet::Type.type(:file).ensurable do
    require 'etc'
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode

    desc <<-EOT
      Whether the file should exist, and if so what kind of file it should be.
      Possible values are `present`, `absent`, `file`, `directory`, and `link`.

      * `present` accepts any form of file existence, and creates a
        normal file if the file is missing. (The file will have no content
        unless the `content` or `source` attribute is used.)
      * `absent` ensures the file doesn't exist, and deletes it if necessary.
      * `file` ensures it's a normal file, and enables use of the `content` or
        `source` attribute.
      * `directory` ensures it's a directory, and enables use of the `source`,
        `recurse`, `recurselimit`, `ignore`, and `purge` attributes.
      * `link` ensures the file is a symlink, and **requires** that you also
        set the `target` attribute. Symlinks are supported on all Posix
        systems and on Windows Vista / 2008 and higher. On Windows, managing
        symlinks requires Puppet agent's user account to have the "Create
        Symbolic Links" privilege; this can be configured in the "User Rights
        Assignment" section in the Windows policy editor. By default, Puppet
        agent runs as the Administrator account, which has this privilege.

      Puppet avoids destroying directories unless the `force` attribute is set
      to `true`. This means that if a file is currently a directory, setting
      `ensure` to anything but `directory` or `present` will cause Puppet to
      skip managing the resource and log either a notice or an error.

      There is one other non-standard value for `ensure`. If you specify the
      path to another file as the ensure value, it is equivalent to specifying
      `link` and using that path as the `target`:

          # Equivalent resources:

          file { '/etc/inetd.conf':
            ensure => '/etc/inet/inetd.conf',
          }

          file { '/etc/inetd.conf':
            ensure => link,
            target => '/etc/inet/inetd.conf',
          }

      However, we recommend using `link` and `target` explicitly, since this
      behavior can be harder to read and is
      [deprecated](https://docs.puppetlabs.com/puppet/4.3/reference/deprecated_language.html)
      as of Puppet 4.3.0.
    EOT

    # Most 'ensure' properties have a default, but with files we, um, don't.
    nodefault

    newvalue(:absent) do
      Puppet::FileSystem.unlink(@resource[:path])
    end

    aliasvalue(:false, :absent)

    newvalue(:file, :event => :file_created) do
      # Make sure we're not managing the content some other way
      if property = @resource.property(:content)
        property.sync
      elsif property = @resource.property(:checksum_value)
        property.sync
      else
        @resource.write
        @resource.should(:mode)
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
      unless Puppet::FileSystem.exist? parent
        raise Puppet::Error,
          "Cannot create #{@resource[:path]}; parent directory #{parent} does not exist"
      end
      if mode
        Puppet::Util.withumask(000) do
          Dir.mkdir(@resource[:path], symbolic_mode_to_int(mode, 0755, true))
        end
      else
        Dir.mkdir(@resource[:path])
      end
      @resource.send(:property_fix)
      return :directory_created
    end


    newvalue(:link, :event => :link_created, :required_features => :manages_symlinks) do
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
      return super unless [:file, :present].include?(newvalue)

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

      if ! Puppet::FileSystem.exist?(basedir)
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

