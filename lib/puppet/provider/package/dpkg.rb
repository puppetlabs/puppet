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
    cmd = "#{command(:dpkgquery)} -W --showformat '#{self::DPKG_QUERY_FORMAT_STRING}'"
    Puppet.debug "Executing '#{cmd}'"
    Puppet::Util::Execution.execpipe(cmd) do |process|
      until process.eof?
        hash = parse_multi_line(process)
        packages << new(hash) if hash
      end
    end

    packages
  end

  # dpkg-query Description field has a one line summary and a multi-line
  # description.  dpkg-query binary:Summary is what we want to use but was
  # introduced in 2012 dpkg 1.16.2
  # (https://launchpad.net/debian/+source/dpkg/1.16.2) and is not not available
  # in older Debian versions.  So we're placing a delimiter marker at the end
  # of the description so we can consume and ignore the multiline description
  # without issuing warnings
  self::DPKG_DESCRIPTION_DELIMITER = ':DESC:'
  self::DPKG_QUERY_FORMAT_STRING = %Q{${Status} ${Package} ${Version} #{self::DPKG_DESCRIPTION_DELIMITER}${Description}\\n#{self::DPKG_DESCRIPTION_DELIMITER}\\n}
  self::REGEX = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*) #{self::DPKG_DESCRIPTION_DELIMITER}(.+)$}
  self::FIELDS = [:desired, :error, :status, :name, :ensure, :description]

  # Handles parsing one package's worth of multi-line dpkg-query output.  Will
  # emit warnings if it encounters an initial line that does not match
  # DPKG_QUERY_FORMAT_STRING.  Swallows extra description lines silently.
  #
  # @param output [IO,String] something that respond's to each_line
  # @return [Hash] parsed dpkg-entry as a hash of FIELDS
  # @api private
  def self.parse_multi_line(output)
    # now turn each returned entry into a package object
    hash = nil

    # this would be simpler with IO#gets, but we also handle a string
    # in Dpkg#query.
    output.each_line { |line|
      if hash # already parsed from first line
        break if line.match(/^#{self::DPKG_DESCRIPTION_DELIMITER}\n/)
        next # otherwise skip through extra description lines
      else
        unless hash = parse_line(line)
          # bad entry altogether
          Puppet.warning "Failed to match dpkg-query line #{line.inspect}"
          return nil
        end
      end
    }
    return hash
  end

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

    hash = {}

    # list out our specific package
    begin
      output = dpkgquery(
        "-W",
        "--showformat",
        self.class::DPKG_QUERY_FORMAT_STRING, 
        @resource[:name]
      )
    rescue Puppet::ExecutionFailure
      # dpkg-query exits 1 if the package is not found.
      return {:ensure => :purged, :status => 'missing', :name => @resource[:name], :error => 'ok'}
    end

    hash = self.class.parse_multi_line(output) || {:ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok'}

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
    Tempfile.open('puppet_dpkg_set_selection') do |tmpfile|
      tmpfile.write("#{@resource[:name]} hold\n")
      tmpfile.flush
      execute([:dpkg, "--set-selections"], :failonfail => false, :combine => false, :stdinfile => tmpfile.path.to_s)
    end
  end

  def unhold
    Tempfile.open('puppet_dpkg_set_selection') do |tmpfile|
      tmpfile.write("#{@resource[:name]} install\n")
      tmpfile.flush
      execute([:dpkg, "--set-selections"], :failonfail => false, :combine => false, :stdinfile => tmpfile.path.to_s)
    end
  end
end
