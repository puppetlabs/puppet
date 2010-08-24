Puppet::Type.type(:package).provide :zypper, :parent => :rpm do
  desc "Support for SuSE `zypper` package manager. Found in SLES10sp2+ and SLES11"

  has_feature :versionable

  commands :zypper => "/usr/bin/zypper"
  commands :rpm    => "rpm"

  confine    :operatingsystem => [:suse, :sles, :sled, :opensuse]

  # Install a package using 'zypper'.
  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]

    # XXX: We don't actually deal with epochs here.
    case should
    when true, false, Symbol
      # pass
    else
      # Add the package version
      wanted = "#{wanted}-#{should}"
    end
    output = zypper "--quiet", :install, "-l", "-y", wanted

    unless self.query
      raise Puppet::ExecutionFailure.new(
        "Could not find package #{self.name}"
      )
    end
  end

  # What's the latest package version available?
  def latest
    #zypper can only get a list of *all* available packages?
    output = zypper "list-updates"

    if output =~ /#{Regexp.escape @resource[:name]}\s*\|\s*([^\s\|]+)/
      return $1
    else
      # zypper didn't find updates, pretend the current
      # version is the latest
      return @property_hash[:ensure]
    end
  end

  def update
    # zypper install can be used for update, too
    self.install
  end
end
