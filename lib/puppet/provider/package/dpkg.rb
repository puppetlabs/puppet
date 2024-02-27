# frozen_string_literal: true

require_relative '../../../puppet/provider/package'

Puppet::Type.type(:package).provide :dpkg, :parent => Puppet::Provider::Package do
  desc "Package management via `dpkg`.  Because this only uses `dpkg`
    and not `apt`, you must specify the source of any packages you want
    to manage."

  has_feature :holdable, :virtual_packages
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
        hash = parse_line(line)
        if hash
          packages << new(hash)
        end
      end
    end

    packages
  end

  private

  # Note: self:: is required here to keep these constants in the context of what will
  # eventually become this Puppet::Type::Package::ProviderDpkg class.
  self::DPKG_QUERY_FORMAT_STRING = %q('${Status} ${Package} ${Version}\\n')
  self::DPKG_QUERY_PROVIDES_FORMAT_STRING = %q('${Status} ${Package} ${Version} [${Provides}]\\n')
  self::FIELDS_REGEX = %r{^'?(\S+) +(\S+) +(\S+) (\S+) (\S*)$}
  self::FIELDS_REGEX_WITH_PROVIDES = %r{^'?(\S+) +(\S+) +(\S+) (\S+) (\S*) \[.*\]$}
  self::FIELDS = [:desired, :error, :status, :name, :ensure]

  def self.defaultto_allow_virtual
    false
  end

  # @param line [String] one line of dpkg-query output
  # @return [Hash,nil] a hash of FIELDS or nil if we failed to match
  # @api private
  def self.parse_line(line, regex = self::FIELDS_REGEX)
    hash = nil

    match = regex.match(line)
    if match
      hash = {}

      self::FIELDS.zip(match.captures) do |field, value|
        hash[field] = value
      end

      hash[:provider] = self.name

      if hash[:status] == 'not-installed'
        hash[:ensure] = :purged
      elsif ['config-files', 'half-installed', 'unpacked', 'half-configured'].include?(hash[:status])
        hash[:ensure] = :absent
      end
      hash[:mark] = hash[:desired] == 'hold' ? :hold : :none
    else
      Puppet.debug("Failed to match dpkg-query line #{line.inspect}")
    end

    return hash
  end

  public

  def install
    file = @resource[:source]
    unless file
      raise ArgumentError, _("You cannot install dpkg packages without a source")
    end

    args = []

    if @resource[:configfiles] == :keep
      args << '--force-confold'
    else
      args << '--force-confnew'
    end
    args << '-i' << file

    self.unhold if self.properties[:mark] == :hold
    begin
      dpkg(*args)
    ensure
      self.hold if @resource[:mark] == :hold
    end
  end

  def update
    self.install
  end

  # Return the version from the package.
  def latest
    source = @resource[:source]
    unless source
      @resource.fail _("Could not update: You cannot install dpkg packages without a source")
    end
    output = dpkg_deb "--show", source
    matches = /^(\S+)\t(\S+)$/.match(output).captures
    warning _("source doesn't contain named package, but %{name}") % { name: matches[0] } unless matches[0].match(Regexp.escape(@resource[:name]))
    matches[1]
  end

  def query
    hash = nil

    # list out our specific package
    begin
      if @resource.allow_virtual?
        output = dpkgquery(
          "-W",
          "--showformat",
          self.class::DPKG_QUERY_PROVIDES_FORMAT_STRING
          # the regex searches for the resource[:name] in the dpkquery result in which the Provides field is also available
          # it will search for the packages only in the brackets ex: [rubygems]
        ).lines.find { |package| package.match(/[\[ ](#{Regexp.escape(@resource[:name])})[\],]/) }
        if output
          hash = self.class.parse_line(output, self.class::FIELDS_REGEX_WITH_PROVIDES)
          Puppet.info("Package #{@resource[:name]} is virtual, defaulting to #{hash[:name]}")
          @resource[:name] = hash[:name]
        end
      end
      output = dpkgquery(
        "-W",
        "--showformat",
        self.class::DPKG_QUERY_FORMAT_STRING,
        @resource[:name]
      )
      hash = self.class.parse_line(output)
    rescue Puppet::ExecutionFailure
      # dpkg-query exits 1 if the package is not found.
      return { :ensure => :purged, :status => 'missing', :name => @resource[:name], :error => 'ok' }
    end

    hash ||= { :ensure => :absent, :status => 'missing', :name => @resource[:name], :error => 'ok' }

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
