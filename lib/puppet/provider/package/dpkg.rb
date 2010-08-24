require 'puppet/provider/package'

Puppet::Type.type(:package).provide :dpkg, :parent => Puppet::Provider::Package do
  desc "Package management via `dpkg`.  Because this only uses `dpkg`
    and not `apt`, you must specify the source of any packages you want
    to manage."

  has_feature :holdable

  commands :dpkg => "/usr/bin/dpkg"
  commands :dpkg_deb => "/usr/bin/dpkg-deb"
  commands :dpkgquery => "/usr/bin/dpkg-query"

  def self.instances
    packages = []

    # list out all of the packages
    cmd = "#{command(:dpkgquery)} -W --showformat '${Status} ${Package} ${Version}\\n'"
    Puppet.debug "Executing '#{cmd}'"
    execpipe(cmd) do |process|
      # our regex for matching dpkg output
      regex = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
      fields = [:desired, :error, :status, :name, :ensure]
      hash = {}

      # now turn each returned line into a package object
      process.each { |line|
        if hash = parse_line(line)
          packages << new(hash)
        end
      }
    end

    packages
  end

  self::REGEX = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
  self::FIELDS = [:desired, :error, :status, :name, :ensure]

  def self.parse_line(line)
    if match = self::REGEX.match(line)
      hash = {}

      self::FIELDS.zip(match.captures) { |field,value|
        hash[field] = value
      }

      hash[:provider] = self.name

      if hash[:status] == 'not-installed'
        hash[:ensure] = :purged
      elsif ['config-files', 'half-installed', 'unpacked', 'half-configured'].include?(hash[:status])
        hash[:ensure] = :absent
      end
      hash[:ensure] = :held if hash[:desired] == 'hold'
    else
      Puppet.warning "Failed to match dpkg-query line #{line.inspect}"
      return nil
    end

    hash
  end

  def install
    unless file = @resource[:source]
      raise ArgumentError, "You cannot install dpkg packages without a source"
    end

    args = []

    # We always unhold when installing to remove any prior hold.
    self.unhold

    if @resource[:configfiles] == :keep
      args << '--force-confold'
    else
      args << '--force-confnew'
    end
    args << '-i' << file

    dpkg(*args)
  end

  def update
    self.install
  end

  # Return the version from the package.
  def latest
    output = dpkg_deb "--show", @resource[:source]
    matches = /^(\S+)\t(\S+)$/.match(output).captures
    warning "source doesn't contain named package, but #{matches[0]}" unless matches[0].match( Regexp.escape(@resource[:name]) )
    matches[1]
  end

  def query
    packages = []

    fields = [:desired, :error, :status, :name, :ensure]

    hash = {}

    # list out our specific package
    begin

            output = dpkgquery(
        "-W", "--showformat",
        
        '${Status} ${Package} ${Version}\\n', @resource[:name]
      )
    rescue Puppet::ExecutionFailure
      # dpkg-query exits 1 if the package is not found.
      return {:ensure => :purged, :status => 'missing', :name => @resource[:name], :error => 'ok'}

    end

    hash = self.class.parse_line(output) || {:ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok'}

    if hash[:error] != "ok"
      raise Puppet::Error.new(
        "Package #{hash[:name]}, version #{hash[:ensure]} is in error state: #{hash[:error]}"
      )
    end

    hash
  end

  def uninstall
    dpkg "-r", @resource[:name]
  end

  def purge
    dpkg "--purge", @resource[:name]
  end

  def hold
    self.install
    begin
      Tempfile.open('puppet_dpkg_set_selection') { |tmpfile|
        tmpfile.write("#{@resource[:name]} hold\n")
        tmpfile.flush
        execute([:dpkg, "--set-selections"], :stdinfile => tmpfile.path.to_s)
      }
    end
  end

  def unhold
    begin
      Tempfile.open('puppet_dpkg_set_selection') { |tmpfile|
        tmpfile.write("#{@resource[:name]} install\n")
        tmpfile.flush
        execute([:dpkg, "--set-selections"], :stdinfile => tmpfile.path.to_s)
      }
    end
  end
end
