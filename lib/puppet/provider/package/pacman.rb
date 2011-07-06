require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pacman, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (pacman) used in Archlinux."

  commands :pacman => "/usr/bin/pacman"
  defaultfor :operatingsystem => :archlinux
  confine    :operatingsystem => :archlinux
  has_feature :upgradeable

  # Install a package using 'pacman'.
  # Installs quietly, without confirmation or progressbar, updates package
  # list from servers defined in pacman.conf.
  def install
    pacman "--noconfirm", "--noprogressbar", "-Sy", @resource[:name]

    unless self.query
      raise Puppet::ExecutionFailure.new("Could not find package %s" % self.name)
    end
  end

  def self.listcmd
    [command(:pacman), " -Q"]
  end

  # Fetch the list of packages currently installed on the system.
  def self.instances
    packages = []
    begin
      execpipe(listcmd()) do |process|
        # pacman -Q output is 'packagename version-rel'
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
    # Install in pacman can be used for update, too
    self.install
  end

  def latest
    pacman "-Sy"
    output = pacman "-Sp", "--print-format", "%v", @resource[:name]
    output.chomp
  end

  # Querys the pacman master list for information about the package.
  def query
    begin
      output = pacman("-Qi", @resource[:name])

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
    pacman "--noconfirm", "--noprogressbar", "-R", @resource[:name]
  end
end
