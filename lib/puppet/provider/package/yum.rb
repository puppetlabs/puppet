require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care."

  has_feature :install_options, :versionable

  commands :yum => "yum", :rpm => "rpm", :python => "python"

  self::YUMHELPER = File::join(File::dirname(__FILE__), "yumhelper.py")

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :operatingsystem => [:fedora, :centos, :redhat]

  def self.prefetch(packages)
    raise Puppet::Error, "The yum provider can only be used as root" if Process.euid != 0
    super
  end

  # Retrieve the latest package version information for a given package name.
  #
  # @api private
  # @param package [String] The name of the package to query
  # @return [Hash<Symbol, String>]
  def self.latest_package_version(package)
    if @latest_versions.nil?
      @latest_versions = fetch_latest_versions
    end

    @latest_versions[package].first
  end

  # Search for all installed packages that have newer versions.
  #
  # @api private
  # @return [Hash<String, Array<Hash<String, String>>>]
  def self.fetch_latest_versions
    latest_versions = Hash.new {|h, k| h[k] = []}

    python(self::YUMHELPER).each_line do |l|
      if (match = l.match /^_pkg (.*)$/)
        hash = nevra_to_hash(match[1])

        short_name = hash[:name]
        long_name  = "#{hash[:name]}.#{hash[:arch]}"

        latest_versions[short_name] << hash
        latest_versions[long_name]  << hash
      end
    end
    latest_versions
  end

  def self.clear
    @latest_versions = nil
  end

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      is = self.query
      if is && Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
        operation = :downgrade
      end
    end

    args = ["-d", "0", "-e", "0", "-y", install_options, operation, wanted].compact
    yum *args


    is = self.query
    raise Puppet::Error, "Could not find package #{self.name}" unless is

    # FIXME: Should we raise an exception even if should == :latest
    # and yum updated us to a version other than @param_hash[:ensure] ?
    raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if should && should != is[:ensure]
  end

  # What's the latest package version available?
  def latest
    upd = self.class.latest_package_version(@resource[:name])
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current
      # version is the latest
      raise Puppet::DevError, "Tried to get latest on a missing package" if properties[:ensure] == :absent
      return properties[:ensure]
    end
  end

  def update
    # Install in yum can be used for update, too
    self.install
  end

  def purge
    yum "-y", :erase, @resource[:name]
  end

  # @deprecated
  def latest_info
    Puppet.deprecation_warning("#{self.class}#{__method__} is deprecated and no longer used")
    @latest_info
  end

  # @deprecated
  def latest_info=(latest)
    Puppet.deprecation_warning("#{self.class}#{__method__} is deprecated and no longer used")
    @latest_info = latest
  end
end
