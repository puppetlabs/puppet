Puppet::Type.type(:package).provide :aptitude, :parent => :apt, :source => :dpkg do
  desc "Package management via `aptitude`."

  has_feature :versionable

  commands :aptitude => "/usr/bin/aptitude"
  commands :aptcache => "/usr/bin/apt-cache"

  ENV['DEBIAN_FRONTEND'] = "noninteractive"

  def aptget(*args)
    args.flatten!
    # Apparently aptitude hasn't always supported a -q flag.
    args.delete("-q") if args.include?("-q")
    args.delete("--force-yes") if args.include?("--force-yes")
    output = aptitude(*args)

    # Yay, stupid aptitude doesn't throw an error when the package is missing.
    if args.include?(:install) and output =~ /Couldn't find any package/
      raise Puppet::Error.new(
        _("Could not find package %{name}") % { name: self.name }
      )
    end
  end

  def purge
    aptitude '-y', 'purge', @resource[:name]
  end
end
