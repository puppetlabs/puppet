# Packaging using Peter Bonivart's pkgutil program.
Puppet::Type.type(:package).provide :pkgutil, :parent => :sun, :source => :sun do
  desc "Package management using Peter Bonivart's ``pkgutil`` command on Solaris."

  pkgutil_bin = "pkgutil"
  if FileTest.executable?("/opt/csw/bin/pkgutil")
    pkgutil_bin = "/opt/csw/bin/pkgutil"
  end

  confine :osfamily => :solaris

  has_command(:pkguti, pkgutil_bin) do
    environment :HOME => ENV['HOME']
  end

  def self.healthcheck()
    unless Puppet::FileSystem.exist?("/var/opt/csw/pkgutil/admin")
      Puppet.notice "It is highly recommended you create '/var/opt/csw/pkgutil/admin'."
      Puppet.notice "See /var/opt/csw/pkgutil"
    end

    correct_wgetopts = false
    [ "/opt/csw/etc/pkgutil.conf", "/etc/opt/csw/pkgutil.conf" ].each do |confpath|
      File.open(confpath) do |conf|
        conf.each_line {|line| correct_wgetopts = true if line =~ /^\s*wgetopts\s*=.*(-nv|-q|--no-verbose|--quiet)/ }
      end
    end
    if ! correct_wgetopts
      Puppet.notice "It is highly recommended that you set 'wgetopts=-nv' in your pkgutil.conf."
    end
  end

  def self.instances(hash = {})
    healthcheck

    # Use the available pkg list (-a) to work out aliases
    aliases = {}
    availlist.each do |pkg|
      aliases[pkg[:name]] = pkg[:alias]
    end

    # The -c pkglist lists installed packages
    pkginsts = []
    output = pkguti(["-c"])
    parse_pkglist(output).each do |pkg|
      pkg.delete(:avail)
      pkginsts << new(pkg)

      # Create a second instance with the alias if it's different
      pkgalias = aliases[pkg[:name]]
      if pkgalias and pkg[:name] != pkgalias
        apkg = pkg.dup
        apkg[:name] = pkgalias
        pkginsts << new(apkg)
      end
    end

    pkginsts
  end

  # Turns a pkgutil -a listing into hashes with the common alias, full
  # package name and available version
  def self.availlist
    output = pkguti ["-a"]

    output.split("\n").collect do |line|
      next if line =~ /^common\s+package/  # header of package list
      next if noise?(line)

      if line =~ /\s*(\S+)\s+(\S+)\s+(.*)/
        { :alias => $1, :name => $2, :avail => $3 }
      else
        Puppet.warning "Cannot match %s" % line
      end
    end.reject { |h| h.nil? }
  end

  # Turn our pkgutil -c listing into a hash for a single package.
  def pkgsingle(resource)
    # The --single option speeds up the execution, because it queries
    # the package management system for one package only.
    command = ["-c", "--single", resource[:name]]
    self.class.parse_pkglist(run_pkgutil(resource, command), { :justme => resource[:name] })
  end

  # Turn our pkgutil -c listing into a bunch of hashes.
  def self.parse_pkglist(output, hash = {})
    output = output.split("\n")

    if output[-1] == "Not in catalog"
      Puppet.warning "Package not in pkgutil catalog: %s" % hash[:justme]
      return nil
    end

    list = output.collect do |line|
      next if line =~ /installed\s+catalog/  # header of package list
      next if noise?(line)

      pkgsplit(line)
    end.reject { |h| h.nil? }

    if hash[:justme]
      # Single queries may have been for an alias so return the name requested
      if list.any?
        list[-1][:name] = hash[:justme]
        return list[-1]
      end
    else
      list.reject! { |h| h[:ensure] == :absent }
      return list
    end
  end

  # Identify common types of pkgutil noise as it downloads catalogs etc
  def self.noise?(line)
    true if line =~ /^#/
    true if line =~ /^Checking integrity / # use_gpg
    true if line =~ /^gpg: /               # gpg verification
    true if line =~ /^=+> /                # catalog fetch
    true if line =~ /\d+:\d+:\d+ URL:/     # wget without -q
    false
  end

  # Split the different lines into hashes.
  def self.pkgsplit(line)
    if line =~ /\s*(\S+)\s+(\S+)\s+(.*)/
      hash = {}
      hash[:name] = $1
      hash[:ensure] = if $2 == "notinst"
        :absent
      else
        $2
      end
      hash[:avail] = $3

      if hash[:avail] =~ /^SAME\s*$/
        hash[:avail] = hash[:ensure]
      end

      # Use the name method, so it works with subclasses.
      hash[:provider] = self.name

      return hash
    else
      Puppet.warning "Cannot match %s" % line
      return nil
    end
  end

  def run_pkgutil(resource, *args)
    # Allow source to be one or more URLs pointing to a repository that all
    # get passed to pkgutil via one or more -t options
    if resource[:source]
      sources = [resource[:source]].flatten
      pkguti *[sources.map{|src| [ "-t", src ]}, *args].flatten
    else
      pkguti *args.flatten
    end
  end

  def install
    run_pkgutil @resource, "-y", "-i", @resource[:name]
  end

  # Retrieve the version from the current package file.
  def latest
    hash = pkgsingle(@resource)
    hash[:avail] if hash
  end

  def query
    if hash = pkgsingle(@resource)
      hash
    else
      {:ensure => :absent}
    end
  end

  def update
    run_pkgutil @resource, "-y", "-u", @resource[:name]
  end

  def uninstall
    run_pkgutil @resource, "-y", "-r", @resource[:name]
  end
end
