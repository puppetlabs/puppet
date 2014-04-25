Puppet::Type.type(:package).provide :apt, :parent => :dpkg, :source => :dpkg do
  # Provide sorting functionality
  include Puppet::Util::Package

  desc "Package management via `apt-get`.

    This provider supports the `install_options` attribute, which allows command-line flags to be passed to apt-get.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash."

  has_feature :versionable, :install_options

  commands :aptget => "/usr/bin/apt-get"
  commands :aptcache => "/usr/bin/apt-cache"
  commands :preseed => "/usr/bin/debconf-set-selections"

  defaultfor :operatingsystem => [:debian, :ubuntu]

  ENV['DEBIAN_FRONTEND'] = "noninteractive"

  # disable common apt helpers to allow non-interactive package installs
  ENV['APT_LISTBUGS_FRONTEND'] = "none"
  ENV['APT_LISTCHANGES_FRONTEND'] = "none"

  # A derivative of DPKG; this is how most people actually manage
  # Debian boxes, and the only thing that differs is that it can
  # install packages from remote sites.

  def initialize(value={})
    super(value)
    @property_flush ||= {}
  end

  def checkforcdrom
    have_cdrom = begin
                   !!(File.read("/etc/apt/sources.list") =~ /^[^#]*cdrom:/)
                 rescue
                   # This is basically pathological...
                   false
                 end

    if have_cdrom and @resource[:allowcdrom] != :true
      raise Puppet::Error,
        "/etc/apt/sources.list contains a cdrom source; not installing.  Use 'allowcdrom' to override this failure."
    end
  end

  def install
    @property_flush[:ensure] = :installed
  end

  # Install a package using 'apt-get'.  This function needs to support
  # installing a specific version.
  def flush_install
    self.run_preseed if @resource[:responsefile]

    checkforcdrom
    aptget_options = %w{-q -y}

    if config = @resource[:configfiles]
      if config == :keep
        aptget_options << "-o" << 'DPkg::Options::=--force-confold'
      else
        aptget_options << "-o" << 'DPkg::Options::=--force-confnew'
      end
    end

    package_version = @resource[:ensure].is_a?(String) ? @resource[:ensure] : @resource[:version]
    package_specification = @resource[:name]

    if package_version
      aptget_options << "--force-yes"
      package_specification += "=#{package_version}"
    end

    aptget_options += install_options if @resource[:install_options]
    aptget(*(aptget_options << :install << package_specification))
  end

  def version=(version)
    @property_flush[:ensure] = :installed
  end

  # What's the latest package version available?
  def latest
    output = aptcache :policy,  @resource[:name]

    if output =~ /Candidate:\s+(\S+)\s/
      return $1
    else
      self.err "Could not find latest version"
      return nil
    end
  end

  #
  # preseeds answers to dpkg-set-selection from the "responsefile"
  #
  def run_preseed
    if response = @resource[:responsefile] and Puppet::FileSystem.exist?(response)
      self.info("Preseeding #{response} to debconf-set-selections")

      preseed response
    else
      self.info "No responsefile specified or non existant, not preseeding anything"
    end
  end

  def uninstall
    self.run_preseed if @resource[:responsefile]
    aptget "-y", "-q", :remove, @resource[:name]
  end

  def purge
    self.run_preseed if @resource[:responsefile]
    aptget '-y', '-q', :remove, '--purge', @resource[:name]
    # workaround a "bug" in apt, that already removed packages are not purged
    super
  end

  def install_options
    join_options(@resource[:install_options])
  end

  def flush
    super
  end
end
