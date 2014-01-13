require 'puppet/provider/package'

Puppet::Type.type(:package).provide :dpkg, :parent => Puppet::Provider::Package do
  desc "Package management via `dpkg`.  Because this only uses `dpkg`
    and not `apt`, you must specify the source of any packages you want
    to manage."

  has_feature :holdable

  commands :dpkg => "/usr/bin/dpkg"
  commands :dpkg_deb => "/usr/bin/dpkg-deb"
  commands :dpkgquery => "/usr/bin/dpkg-query"

  # Performs a dpkgquery call with a pipe so that output can be processed
  # inline in a passed block.
  # @param args [Array<String>] any command line arguments to be appended to the command
  # @param block expected to be passed on to execpipe
  # @return whatever the block returns
  # @see Puppet::Util::Execution.execpipe
  # @api private
  def self.dpkgquery_piped(*args, &block)
    cmd = args.unshift(command(:dpkgquery))
    Puppet::Util::Execution.execpipe(cmd, &block)
  end

  def self.instances
    packages = []

    # list out all of the packages
    dpkgquery_piped('-W', '--showformat', self::DPKG_QUERY_FORMAT_STRING) do |pipe|
      # now turn each returned line into a package object
      pipe.each_line do |line|
        if hash = parse_line(line)
          packages << new(hash)
        end
      end
    end

    packages
  end

  private

  # Note: self:: is required here to keep these constants in the context of what will
  # eventually become this Puppet::Type::Package::ProviderDpkg class.
  self::DPKG_QUERY_FORMAT_STRING = %Q{'${Status} ${Package} ${Version}\\n'}
  self::FIELDS_REGEX = %r{^(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
  self::FIELDS= [:desired, :error, :status, :name, :ensure]

  # @param line [String] one line of dpkg-query output
  # @return [Hash,nil] a hash of FIELDS or nil if we failed to match
  # @api private
  def self.parse_line(line)
    hash = nil

    if match = self::FIELDS_REGEX.match(line)
      hash = {}

      self::FIELDS.zip(match.captures) do |field,value|
        hash[field] = value
      end

      hash[:provider] = self.name

      if hash[:status] == 'not-installed'
        hash[:ensure] = :purged
      elsif ['config-files', 'half-installed', 'unpacked', 'half-configured'].include?(hash[:status])
        hash[:ensure] = :absent
      end
      hash[:ensure] = :held if hash[:desired] == 'hold'
    else 
      Puppet.debug("Failed to match dpkg-query line #{line.inspect}")
    end

    return hash
  end

  public

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
    hash = nil

    # list out our specific package
    begin
      output = dpkgquery(
        "-W",
        "--showformat",
        self.class::DPKG_QUERY_FORMAT_STRING,
        @resource[:name]
      )
      hash = self.class.parse_line(output)
    rescue Puppet::ExecutionFailure
      # dpkg-query exits 1 if the package is not found.
      return {:ensure => :purged, :status => 'missing', :name => @resource[:name], :error => 'ok'}
    end

    hash ||= {:ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok'}

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
