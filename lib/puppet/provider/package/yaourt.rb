require 'puppet/provider/package'

Puppet::Type.type(:package).provide :yaourt, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (yaourt) used in Archlinux."

  commands :yaourt => "/usr/bin/yaourt"
  defaultfor :operatingsystem => :archlinux
  confine    :operatingsystem => :archlinux
  has_feature :upgradeable

  # Install a package using 'yaourt'.
  # Installs quietly, without confirmation or progressbar, updates package
  # list from servers defined in yaourt.conf.
  def install
    yaourt "--noconfirm", "-Sy", @resource[:name]

    unless self.query
      raise Puppet::ExecutionFailure.new("Could not find package %s" % self.name)
    end
  end

  def self.listcmd
    [command(:yaourt), " -Q"]
  end

  # Fetch the list of packages currently installed on the system.
  def self.instances
    packages = []
    begin
      execpipe(listcmd()) do |process|
        # yaourt -Q output is 'packagename version-rel'
        regex = %r{^(\S+)\s(\S+)}
        fields = [:name, :ensure]
        hash = {}

        process.each_line { |line|
          if match = regex.match(line)
            fields.zip(match.captures) { |field,value|
              hash[field] = value
            }

            name = hash[:name]
            hash[:provider] = self.name

            packages << new(hash)
            hash = {}
          else
            warning("Failed to match line %s" % line)
          end
        }
      end
    rescue Puppet::ExecutionFailure
      return nil
    end
    packages
  end

  # Because Archlinux is a rolling release based distro, installing a package
  # should always result in the newest release.
  def update
    # Install in yaourt can be used for update, too
    self.install
  end

  def latest
    yaourt "-Sy"
    output = yaourt "-Sp", "--print-format", "%v", @resource[:name]
    output.chomp
  end

  # Querys the yaourt master list for information about the package.
  def query
    begin
      output = yaourt("-Qi", @resource[:name])

      if output =~ /Version.*:\s(.+)/
        return { :ensure => $1 }
      end
    rescue Puppet::ExecutionFailure
      return {
        :ensure => :purged,
        :status => 'missing',
        :name => @resource[:name],
        :error => 'ok',
      }
    end
    nil
  end

  # Removes a package from the system.
  def uninstall
    yaourt "--noconfirm", "-R", @resource[:name]
  end
end
