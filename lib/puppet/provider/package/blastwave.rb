# Packaging using Blastwave's pkg-get program.
Puppet::Type.type(:package).provide :blastwave, :parent => :sun, :source => :sun do
  desc "Package management using Blastwave.org's `pkg-get` command on Solaris."
  pkgget = "pkg-get"
  pkgget = "/opt/csw/bin/pkg-get" if FileTest.executable?("/opt/csw/bin/pkg-get")

  confine :osfamily => :solaris

  commands :pkgget => pkgget

  def pkgget_with_cat(*args)
    Puppet::Util.withenv(:PAGER => "/usr/bin/cat") { pkgget(*args) }
  end

  def self.extended(mod)
    unless command(:pkgget) != "pkg-get"
      raise Puppet::Error,
        "The pkg-get command is missing; blastwave packaging unavailable"
    end

    unless Puppet::FileSystem.exist?("/var/pkg-get/admin")
      Puppet.notice "It is highly recommended you create '/var/pkg-get/admin'."
      Puppet.notice "See /var/pkg-get/admin-fullauto"
    end
  end

  def self.instances(hash = {})
    blastlist(hash).collect do |bhash|
      bhash.delete(:avail)
      new(bhash)
    end
  end

  # Turn our blastwave listing into a bunch of hashes.
  def self.blastlist(hash)
    command = ["-c"]

    command << hash[:justme] if hash[:justme]

    output = Puppet::Util.withenv(:PAGER => "/usr/bin/cat") { pkgget command }

    list = output.split("\n").collect do |line|
      next if line =~ /^#/
      next if line =~ /^WARNING/
      next if line =~ /localrev\s+remoterev/

      blastsplit(line)
    end.reject { |h| h.nil? }

    if hash[:justme]
      return list[0]
    else
      list.reject! { |h|
        h[:ensure] == :absent
      }
      return list
    end

  end

  # Split the different lines into hashes.
  def self.blastsplit(line)
    if line =~ /\s*(\S+)\s+((\[Not installed\])|(\S+))\s+(\S+)/
      hash = {}
      hash[:name] = $1
      hash[:ensure] = if $2 == "[Not installed]"
        :absent
      else
        $2
      end
      hash[:avail] = $5

      hash[:avail] = hash[:ensure] if hash[:avail] == "SAME"

      # Use the name method, so it works with subclasses.
      hash[:provider] = self.name

      return hash
    else
      Puppet.warning "Cannot match #{line}"
      return nil
    end
  end

  def install
    pkgget_with_cat "-f", :install, @resource[:name]
  end

  # Retrieve the version from the current package file.
  def latest
    hash = self.class.blastlist(:justme => @resource[:name])
    hash[:avail]
  end

  def query
    if hash = self.class.blastlist(:justme => @resource[:name])
      hash
    else
      {:ensure => :absent}
    end
  end

  # Remove the old package, and install the new one
  def update
    pkgget_with_cat "-f", :upgrade, @resource[:name]
  end

  def uninstall
    pkgget_with_cat "-f", :remove, @resource[:name]
  end
end
