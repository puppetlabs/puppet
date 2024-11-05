Puppet::Type.type(:package).provide :rug, :parent => :rpm do
  desc "Support for suse `rug` package manager."

  has_feature :versionable

  commands :rug => "/usr/bin/rug"
  commands :rpm => "rpm"
  confine  'os.name' => [:suse, :sles]

  # Install a package using 'rug'.
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
      wanted += "-#{should}"
    end
    rug "--quiet", :install, "-y", wanted

    unless self.query
      raise Puppet::ExecutionFailure.new(
        _("Could not find package %{name}") % { name: self.name }
      )
    end
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
