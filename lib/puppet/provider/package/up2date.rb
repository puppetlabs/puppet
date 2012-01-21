Puppet::Type.type(:package).provide :up2date, :parent => :rpm, :source => :rpm do
  desc "Support for Red Hat's proprietary `up2date` package update
    mechanism."

  commands :up2date => "/usr/sbin/up2date-nox"

  defaultfor :osfamily => :redhat, :lsbdistrelease => ["2.1", "3", "4"]

  confine    :osfamily => :redhat

  # Install a package using 'up2date'.
  def install
    up2date "-u", @resource[:name]

    unless self.query
      raise Puppet::ExecutionFailure.new(
        "Could not find package #{self.name}"
      )
    end
  end

  # What's the latest package version available?
  def latest
    #up2date can only get a list of *all* available packages?
    output = up2date "--showall"

    if output =~ /^#{Regexp.escape @resource[:name]}-(\d+.*)\.\w+/
      return $1
    else
      # up2date didn't find updates, pretend the current
      # version is the latest
      return @property_hash[:ensure]
    end
  end

  def update
    # Install in up2date can be used for update, too
    self.install
  end
end
