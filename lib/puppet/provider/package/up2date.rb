Puppet::Type.type(:package).provide :up2date, :parent => :rpm, :source => :rpm do
  desc "Support for Red Hat's proprietary `up2date` package update
    mechanism."

  commands :up2date => "/usr/sbin/up2date-nox"

  defaultfor :operatingsystem => [:redhat, :oel, :ovm],
    :lsbdistrelease => ["2.1", "3", "4"]

  confine    :operatingsystem => [:redhat, :oel, :ovm]

  # Install a package using 'up2date'.
  def install
    archs = []
    begin
      execpipe("#{command(:rpm)} --showrc | grep '^compatible arch'") { |output|
      # output is 'compatible arch     : arch arch arch arch...'
      # there should only be one line, but just in case we loop
      output.each { |line|
        # Split up the line after the : on spaces and append to the archs list
        items = line.split(":")[1].split()
          items.each { |item|
            archs << item
          }
        }
      }
    rescue Puppet::ExecutionFailure
      raise Puppet::Error, "Failed to list compatible archs"
    end

    parts = @resource[:name].split(".")
    if archs.index(parts[-1]) != nil
      up2date "--arch", parts[-1], "-u", parts[0..-2].join(".")
    else
      up2date "-u", @resource[:name]
    end

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

