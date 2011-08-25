# Sun packaging.

require 'puppet/provider/package'

Puppet::Type.type(:package).provide :sun, :parent => Puppet::Provider::Package do
  desc "Sun's packaging system.  Requires that you specify the source for
    the packages you're managing."
  commands :pkginfo => "/usr/bin/pkginfo",
    :pkgadd => "/usr/sbin/pkgadd",
    :pkgrm => "/usr/sbin/pkgrm"

  confine :operatingsystem => :solaris

  defaultfor :operatingsystem => :solaris

  def self.instances
    packages = []
    hash = {}
    names = {
      "PKGINST" => :name,
      "NAME" => nil,
      "CATEGORY" => :category,
      "ARCH" => :platform,
      "VERSION" => :ensure,
      "BASEDIR" => :root,
      "HOTLINE" => nil,
      "EMAIL" => nil,
      "VENDOR" => :vendor,
      "DESC" => :description,
      "PSTAMP" => nil,
      "INSTDATE" => nil,
      "STATUS" => nil,
      "FILES" => nil
    }

    cmd = "#{command(:pkginfo)} -l"

    # list out all of the packages
    execpipe(cmd) { |process|
      # we're using the long listing, so each line is a separate
      # piece of information
      process.each { |line|
        case line
        when /^$/
          hash[:provider] = :sun

          packages << new(hash)
          hash = {}
        when /\s*(\w+):\s+(.+)/
          name = $1
          value = $2
          if names.include?(name)
            hash[names[name]] = value unless names[name].nil?
          end
        when /\s+\d+.+/
          # nothing; we're ignoring the FILES info
        end
      }
    }
    packages
  end

  # Get info on a package, optionally specifying a device.
  def info2hash(device = nil)
    names = {
      "PKGINST" => :name,
      "NAME" => nil,
      "CATEGORY" => :category,
      "ARCH" => :platform,
      "VERSION" => :ensure,
      "BASEDIR" => :root,
      "HOTLINE" => nil,
      "EMAIL" => nil,
      "VSTOCK" => nil,
      "VENDOR" => :vendor,
      "DESC" => :description,
      "PSTAMP" => nil,
      "INSTDATE" => nil,
      "STATUS" => nil,
      "FILES" => nil
    }

    hash = {}
    cmd = "#{command(:pkginfo)} -l"
    cmd += " -d #{device}" if device
    cmd += " #{@resource[:name]}"

    begin
      # list out all of the packages
      execpipe(cmd) { |process|
        # we're using the long listing, so each line is a separate
        # piece of information
        process.readlines.each { |line|
          case line
          when /^$/  # ignore
          when /\s*([A-Z]+):\s+(.+)/
            name = $1
            value = $2
            if names.include?(name)
              hash[names[name]] = value unless names[name].nil?
            end
          when /\s+\d+.+/
            # nothing; we're ignoring the FILES info
          end
        }
      }
      return hash
    rescue Puppet::ExecutionFailure => detail
      return {:ensure => :absent} if detail.message =~ /information for "#{Regexp.escape(@resource[:name])}" was not found/
      puts detail.backtrace if Puppet[:trace]
      raise Puppet::Error, "Unable to get information about package #{@resource[:name]} because of: #{detail}"
    end
  end

  def install
    raise Puppet::Error, "Sun packages must specify a package source" unless @resource[:source]
    cmd = []

    cmd << "-a" << @resource[:adminfile] if @resource[:adminfile]

    cmd << "-r" << @resource[:responsefile] if @resource[:responsefile]

    cmd << "-d" << @resource[:source]
    cmd << "-n" << @resource[:name]

    pkgadd cmd
  end

  # Retrieve the version from the current package file.
  def latest
    hash = info2hash(@resource[:source])
    hash[:ensure]
  end

  def query
    info2hash()
  end

  def uninstall
    command  = ["-n"]

    command << "-a" << @resource[:adminfile] if @resource[:adminfile]

    command << @resource[:name]
    pkgrm command
  end

  # Remove the old package, and install the new one.  This will probably
  # often fail.
  def update
    self.uninstall if (@property_hash[:ensure] || info2hash()[:ensure]) != :absent
    self.install
  end
end
