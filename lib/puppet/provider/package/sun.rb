# Sun packaging.

require 'puppet/provider/package'

Puppet::Type.type(:package).provide :sun, :parent => Puppet::Provider::Package do
  desc "Sun's packaging system.  Requires that you specify the source for
    the packages you're managing.

    This provider supports the `install_options` attribute, which allows command-line flags to be passed to pkgadd.
    These options should be specified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}),
    or an array where each element is either a string or a hash."

  commands :pkginfo => "/usr/bin/pkginfo",
    :pkgadd => "/usr/sbin/pkgadd",
    :pkgrm => "/usr/sbin/pkgrm"

  confine :osfamily => :solaris
  defaultfor :osfamily => :solaris

  has_feature :install_options

  self::Namemap = {
    "PKGINST"  => :name,
    "CATEGORY" => :category,
    "ARCH"     => :platform,
    "VERSION"  => :ensure,
    "BASEDIR"  => :root,
    "VENDOR"   => :vendor,
    "DESC"     => :description,
  }

  def self.namemap(hash)
    self::Namemap.keys.inject({}) do |hsh,k|
      hsh.merge(self::Namemap[k] => hash[k])
    end
  end

  def self.parse_pkginfo(out)
    # collect all the lines with : in them, and separate them out by ^$
    pkgs = []
    pkg = {}
    out.each_line do |line|
      case line.chomp
      when /^\s*$/
        pkgs << pkg unless pkg.empty?
        pkg = {}
      when /^\s*([^:]+):\s+(.+)$/
        pkg[$1] = $2
      end
    end
    pkgs << pkg unless pkg.empty?
    pkgs
  end

  def self.instances
    parse_pkginfo(pkginfo('-l')).collect do |p|
      hash = namemap(p)
      hash[:provider] = :sun
      new(hash)
    end
  end

  # Get info on a package, optionally specifying a device.
  def info2hash(device = nil)
    args = ['-l']
    args << '-d' << device if device
    args << @resource[:name]
    begin
      pkgs = self.class.parse_pkginfo(pkginfo(*args))
      errmsg = case pkgs.size
        when 0
          'No message'
        when 1
           pkgs[0]['ERROR']
      end
      return self.class.namemap(pkgs[0]) if errmsg.nil?
      # according to commit 41356a7 some errors do not raise an exception
      # so even though pkginfo passed, we have to check the actual output
      raise Puppet::Error, _("Unable to get information about package %{name} because of: %{errmsg}") % { name: @resource[:name], errmsg: errmsg }
    rescue Puppet::ExecutionFailure
      return {:ensure => :absent}
    end
  end

  # Retrieve the version from the current package file.
  def latest
    info2hash(@resource[:source])[:ensure]
  end

  def query
    info2hash
  end

  # only looking for -G now
  def install
    #TRANSLATORS Sun refers to the company name, do not translate
    raise Puppet::Error, _("Sun packages must specify a package source") unless @resource[:source]
    options = {
      :adminfile    => @resource[:adminfile],
      :responsefile => @resource[:responsefile],
      :source       => @resource[:source],
      :cmd_options  => @resource[:install_options]
    }
    pkgadd prepare_cmd(options)
  end

  def uninstall
    pkgrm prepare_cmd(:adminfile => @resource[:adminfile])
  end

  # Remove the old package, and install the new one.  This will probably
  # often fail.
  def update
    self.uninstall if (@property_hash[:ensure] || info2hash[:ensure]) != :absent
    self.install
  end

  def prepare_cmd(opt)
    [if_have_value('-a', opt[:adminfile]),
     if_have_value('-r', opt[:responsefile]),
     if_have_value('-d', opt[:source]),
     opt[:cmd_options] || [],
     ['-n', @resource[:name]]].flatten
  end

  def if_have_value(prefix, value)
    if value
      [prefix, value]
    else
      []
    end
  end
end
