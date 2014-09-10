Puppet::Type.type(:package).provide :urpmi, :parent => :rpm, :source => :rpm do
  desc "Support via `urpmi`."
  commands :urpmi => "urpmi", :urpmq => "urpmq", :rpm => "rpm", :urpme => "urpme"

  defaultfor :operatingsystem => [:mandriva, :mandrake]

  has_feature :versionable

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]

    # XXX: We don't actually deal with epochs here.
    package_version = @resource[:ensure].is_a?(String) ? @resource[:ensure] : @resource[:version]
    if package_version
      wanted += "-#{package_version}"
    end

    urpmi "--auto", wanted

    unless self.query
      raise Puppet::Error, "Package #{self.name} was not present after trying to install it"
    end
  end

  def version=
    self.install
  end

  # What's the latest package version available?
  def latest
    output = urpmq "-S", @resource[:name]

    if output =~ /^#{Regexp.escape @resource[:name]}\s+:\s+.*\(\s+(\S+)\s+\)/
      return $1
    else
      # urpmi didn't find updates, pretend the current
      # version is the latest
      return @resource[:ensure]
    end
  end

  def update
    # Install in urpmi can be used for update, too
    self.install
  end

  # For normal package removal the urpmi provider will delegate to the RPM
  # provider. If the package to remove has dependencies then uninstalling via
  # rpm will fail, but `urpme` can be used to remove a package and its
  # dependencies.
  def purge
    urpme '--auto', @resource[:name]
  end
end
