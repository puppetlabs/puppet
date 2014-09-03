require 'puppet/provider/package'
require 'set'
require 'uri'

Puppet::Type.type(:package).provide :pacman, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (pacman) used in Archlinux.

  This provider supports the `install_options` attribute, which allows command-line flags to be passed to pacman.
  These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
  or an array where each element is either a string or a hash."

  commands :pacman => "/usr/bin/pacman"
  # Yaourt is a common AUR helper which, if installed, we can use to query the AUR
  commands :yaourt => "/usr/bin/yaourt" if Puppet::FileSystem.exist? '/usr/bin/yaourt'

  confine     :operatingsystem => :archlinux
  defaultfor  :operatingsystem => :archlinux
  has_feature :install_options
  has_feature :uninstall_options
  has_feature :upgradeable

  # If yaourt is installed, we can make use of it
  def yaourt?
    return Puppet::FileSystem.exist?('/usr/bin/yaourt')
  end

  # Install a package using 'pacman', or 'yaourt' if available.
  # Installs quietly, without confirmation or progressbar, updates package
  # list from servers defined in pacman.conf.
  def install
    if @resource[:source]
      install_from_file
    else
      install_from_repo
    end

    unless self.query
      raise Puppet::ExecutionFailure.new("Could not find package %s" % self.name)
    end
  end

  def install_from_repo
    if yaourt?
      cmd = %w{--noconfirm}
      cmd += install_options if @resource[:install_options]
      cmd << "-S" << @resource[:name]
      yaourt *cmd
    else
      cmd = %w{--noconfirm --noprogressbar}
      cmd += install_options if @resource[:install_options]
      cmd << "-Sy" << @resource[:name]
      pacman *cmd
    end
  end
  private :install_from_repo

  def install_from_file
    source = @resource[:source]
    begin
      source_uri = URI.parse source
    rescue => detail
      self.fail Puppet::Error, "Invalid source '#{source}': #{detail}", detail
    end

    source = case source_uri.scheme
    when nil then source
    when /https?/i then source
    when /ftp/i then source
    when /file/i then source_uri.path
    when /puppet/i
      fail "puppet:// URL is not supported by pacman"
    else
      fail "Source #{source} is not supported by pacman"
    end
    pacman "--noconfirm", "--noprogressbar", "-Sy"
    pacman "--noconfirm", "--noprogressbar", "-U", source
  end
  private :install_from_file

  def self.listcmd
    [command(:pacman), "-Q"]
  end

  # Pacman has a concept of package groups as well.
  # Package groups have no versions.
  def self.listgroupcmd
    [command(:pacman), "-Qg"]
  end

  # Get installed packages (pacman -Q)
  def self.installedpkgs
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

  # Get installed groups (pacman -Qg)
  def self.installedgroups
    packages = []
    begin
      execpipe(listgroupcmd()) do |process|
        # pacman -Qg output is 'groupname packagename'
        # Groups need to be deduplicated
        groups = Set[]

        process.each_line { |line|
          groups.add(line.split[0])
        }

        groups.each { |line|
          hash = {
            :name   => line,
            :ensure => "1", # Groups don't have versions, so ensure => latest
                            # will still cause a reinstall.
            :provider => self.name
          }
          packages << new(hash)
        }
      end
    rescue Puppet::ExecutionFailure
      return nil
    end
    packages
  end

  # Fetch the list of packages currently installed on the system.
  def self.instances
    packages = self.installedpkgs
    groups   = self.installedgroups
    result   = nil

    if (!packages && !groups)
      nil
    elsif (packages && groups)
      packages.concat(groups)
    else
      packages
    end
  end


  # Because Archlinux is a rolling release based distro, installing a package
  # should always result in the newest release.
  def update
    # Install in pacman can be used for update, too
    self.install
  end

  # We rescue the main check from Pacman with a check on the AUR using yaourt, if installed
  def latest
    pacman "-Sy"
    pacman_check = true   # Query the main repos first
    begin
      if pacman_check
        output = pacman "-Sp", "--print-format", "%v", @resource[:name]
        return output.chomp
      else
        output = yaourt "-Qma", @resource[:name]
        output.split("\n").each do |line|
          return line.split[1].chomp if line =~ /^aur/
        end
      end
    rescue Puppet::ExecutionFailure
      if pacman_check and self.yaourt?
        pacman_check = false # now try the AUR
        retry
      else
        raise
      end
    end
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
    cmd = %w{--noconfirm --noprogressbar}
    cmd += uninstall_options if @resource[:uninstall_options]
    cmd << "-R" << @resource[:name]
    pacman *cmd
  end

  private

  def install_options
    join_options(@resource[:install_options])
  end

  def uninstall_options
    join_options(@resource[:uninstall_options])
  end
end
