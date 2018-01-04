require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide :aix, :parent => Puppet::Provider::Package do
  desc "Installation from an AIX software directory, using the AIX `installp`
       command.  The `source` parameter is required for this provider, and should
       be set to the absolute path (on the puppet agent machine) of a directory
       containing one or more BFF package files.

       The `installp` command will generate a table of contents file (named `.toc`)
       in this directory, and the `name` parameter (or resource title) that you
       specify for your `package` resource must match a package name that exists
       in the `.toc` file.

       Note that package downgrades are *not* supported; if your resource specifies
       a specific version number and there is already a newer version of the package
       installed on the machine, the resource will fail with an error message."

  # The commands we are using on an AIX box are installed standard
  # (except nimclient) nimclient needs the bos.sysmgt.nim.client fileset.
  commands    :lslpp => "/usr/bin/lslpp",
              :installp => "/usr/sbin/installp"

  # AIX supports versionable packages with and without a NIM server
  has_feature :versionable

  confine  :operatingsystem => [ :aix ]
  defaultfor :operatingsystem => :aix

  attr_accessor   :latest_info

  def self.srclistcmd(source)
    [ command(:installp), "-L", "-d", source ]
  end

  def self.prefetch(packages)
    raise Puppet::Error, _("The aix provider can only be used by root") if Process.euid != 0

    return unless packages.detect { |name, package| package.should(:ensure) == :latest }

    sources = packages.collect { |name, package| package[:source] }.uniq.compact

    updates = {}
    sources.each do |source|
      execute(self.srclistcmd(source)).each_line do |line|
        if line =~ /^[^#][^:]*:([^:]*):([^:]*)/
          current = {}
          current[:name]    = $1
          current[:version] = $2
          current[:source]  = source

          if updates.key?(current[:name])
            previous = updates[current[:name]]

            updates[current[:name]] = current unless Puppet::Util::Package.versioncmp(previous[:version], current[:version]) == 1

          else
            updates[current[:name]] = current
          end
        end
      end
    end

    packages.each do |name, package|
      if updates.key?(name)
        package.provider.latest_info = updates[name]
      end
    end
  end

  def uninstall
    # Automatically process dependencies when installing/uninstalling
    # with the -g option to installp.
    installp "-gu", @resource[:name]

    # installp will return an exit code of zero even if it didn't uninstall
    # anything... so let's make sure it worked.
    unless query().nil?
      self.fail _("Failed to uninstall package '%{name}'") % { name: @resource[:name] }
    end
  end

  def install(useversion = true)
    unless source = @resource[:source]
      self.fail _("A directory is required which will be used to find packages")
    end

    pkg = @resource[:name]

    pkg += " #{@resource.should(:ensure)}" if (! @resource.should(:ensure).is_a? Symbol) and useversion

    output = installp "-acgwXY", "-d", source, pkg

    # If the package is superseded, it means we're trying to downgrade and we
    # can't do that.
    if output =~ /^#{Regexp.escape(@resource[:name])}\s+.*\s+Already superseded by.*$/
      self.fail _("aix package provider is unable to downgrade packages")
    end
  end

  def self.pkglist(hash = {})
    cmd = [command(:lslpp), "-qLc"]

    if name = hash[:pkgname]
      cmd << name
    end

    begin
      list = execute(cmd).scan(/^[^#][^:]*:([^:]*):([^:]*)/).collect { |n,e|
        { :name => n, :ensure => e, :provider => self.name }
      }
    rescue Puppet::ExecutionFailure => detail
      if hash[:pkgname]
        return nil
      else
        raise Puppet::Error, _("Could not list installed Packages: %{detail}") % { detail: detail }, detail.backtrace
      end
    end

    if hash[:pkgname]
      return list.shift
    else
      return list
    end
  end

  def self.instances
    pkglist.collect do |hash|
      new(hash)
    end
  end

  def latest
    upd = latest_info

    unless upd.nil?
      return "#{upd[:version]}"
    else
      raise Puppet::DevError, _("Tried to get latest on a missing package") if properties[:ensure] == :absent

      return properties[:ensure]
    end
  end

  def query
    self.class.pkglist(:pkgname => @resource[:name])
  end

  def update
    self.install(false)
  end
end
