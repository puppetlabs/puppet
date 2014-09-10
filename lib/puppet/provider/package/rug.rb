Puppet::Type.type(:package).provide :rug, :parent => :rpm do
  desc "Support for suse `rug` package manager."

  has_feature :versionable

  commands :rug => "/usr/bin/rug"
  commands :rpm => "rpm"
  defaultfor :operatingsystem => [:suse, :sles]
  confine    :operatingsystem => [:suse, :sles]

  # Install a package using 'rug'.
  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]

    package_version = @resource[:ensure].is_a?(String) ? @resource[:ensure] : @resource[:version]
    # XXX: We don't actually deal with epochs here.
    if package_version
      wanted += "-#{package_version}"
    end
    rug "--quiet", :install, "-y", wanted

    unless self.query
      raise Puppet::ExecutionFailure.new(
        "Could not find package #{self.name}"
      )
    end
  end

  def version=
    self.install
  end

  # What's the latest package version available?
  def latest
    #rug can only get a list of *all* available packages?
    output = rug "list-updates"

    if output =~ /#{Regexp.escape @resource[:name]}\s*\|\s*([^\s\|]+)/
      return $1
    else
      # rug didn't find updates, pretend the current
      # version is the latest
      return @property_hash[:ensure]
    end
  end

  def update
    # rug install can be used for update, too
    self.install
  end
end
