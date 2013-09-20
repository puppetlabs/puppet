require 'puppet/provider/package'
require 'uri'

Puppet::Type.type(:package).provide :pacman, :parent => Puppet::Provider::Package do
  desc "Support for the Package Manager Utility (pacman) used in Archlinux."

  commands :pacman => "/usr/bin/pacman"
  # Yaourt is a common AUR helper which, if installed, we can use to query the AUR
  commands :yaourt => "/usr/bin/yaourt" if File.exists? '/usr/bin/yaourt'

  confine     :operatingsystem => :archlinux
  defaultfor  :operatingsystem => :archlinux
  has_feature :upgradeable

  # If yaourt is installed, we can make use of it
  def yaourt?
    return File.exists? '/usr/bin/yaourt'
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
      yaourt "--noconfirm", "-S", @resource[:name]
    else
        pacman "--noconfirm", "--noprogressbar", "-Sy", @resource[:name]
    end
  end
  private :install_from_repo

  def install_from_file
    source = @resource[:source]
    begin
      source_uri = URI.parse source
    rescue => detail
      fail "Invalid source '#{source}': #{detail}"
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
    pacman "--noconfirm", "--noprogressbar", "-R", @resource[:name]
  end
end
