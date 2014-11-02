Puppet::Type.type(:package).provide :fink, :parent => :dpkg, :source => :dpkg do
  # Provide sorting functionality
  include Puppet::Util::Package

  desc "Package management via `fink`."

  commands :fink => "/sw/bin/fink"
  commands :aptget => "/sw/bin/apt-get"
  commands :aptcache => "/sw/bin/apt-cache"
  commands :dpkgquery => "/sw/bin/dpkg-query"

  has_feature :versionable

  # A derivative of DPKG; this is how most people actually manage
  # Debian boxes, and the only thing that differs is that it can
  # install packages from remote sites.

  def finkcmd(*args)
    fink(*args)
  end

  # Install a package using 'apt-get'.  This function needs to support
  # installing a specific version.
  def install
    self.run_preseed if @resource[:responsefile]
    should = @resource.should(:ensure)

    str = @resource[:name]
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version
      str += "=#{should}"
    end
    cmd = %w{-b -q -y}

    cmd << :install << str

    finkcmd(cmd)
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
      self.info "No responsefile specified or non existent, not preseeding anything"
    end
  end

  def update
    self.install
  end

  def uninstall
    finkcmd "-y", "-q", :remove, @model[:name]
  end

  def purge
    aptget '-y', '-q', 'remove', '--purge', @resource[:name]
  end
end
