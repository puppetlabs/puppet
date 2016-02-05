#
# Motivation: DMG files provide a true HFS file system
# and are easier to manage and .pkg bundles.
#
# Note: the 'apple' Provider checks for the package name
# in /L/Receipts.  Since we install multiple pkg's from a single
# source, we treat the source .pkg.dmg file as the package name.
# As a result, we store installed .pkg.dmg file names
# in /var/db/.puppet_pkgdmg_installed_<name>

require 'puppet/provider/package'
require 'puppet/util/plist' if Puppet.features.cfpropertylist?
require 'puppet/util/http_proxy'

Puppet::Type.type(:package).provide :pkgdmg, :parent => Puppet::Provider::Package do
  desc "Package management based on Apple's Installer.app and DiskUtility.app.

    This provider works by checking the contents of a DMG image for Apple pkg or
    mpkg files. Any number of pkg or mpkg files may exist in the root directory
    of the DMG file system, and Puppet will install all of them. Subdirectories
    are not checked for packages.

    This provider can also accept plain .pkg (but not .mpkg) files in addition
    to .dmg files.

    Notes:

    * The `source` attribute is mandatory. It must be either a local disk path
      or an HTTP, HTTPS, or FTP URL to the package.
    * The `name` of the resource must be the filename (without path) of the DMG file.
    * When installing the packages from a DMG, this provider writes a file to
      disk at `/var/db/.puppet_pkgdmg_installed_NAME`. If that file is present,
      Puppet assumes all packages from that DMG are already installed.
    * This provider is not versionable and uses DMG filenames to determine
      whether a package has been installed. Thus, to install new a version of a
      package, you must create a new DMG with a different filename."

  confine :operatingsystem => :darwin
  confine :feature         => :cfpropertylist
  defaultfor :operatingsystem => :darwin
  commands :installer => "/usr/sbin/installer"
  commands :hdiutil => "/usr/bin/hdiutil"
  commands :curl => "/usr/bin/curl"

  # JJM We store a cookie for each installed .pkg.dmg in /var/db
  def self.instance_by_name
    Dir.entries("/var/db").find_all { |f|
      f =~ /^\.puppet_pkgdmg_installed_/
    }.collect do |f|
      name = f.sub(/^\.puppet_pkgdmg_installed_/, '')
      yield name if block_given?
      name
    end
  end

  def self.instances
    instance_by_name.collect do |name|
      new(:name => name, :provider => :pkgdmg, :ensure => :installed)
    end
  end

  def self.installpkg(source, name, orig_source)
    installer "-pkg", source, "-target", "/"
    # Non-zero exit status will throw an exception.
    File.open("/var/db/.puppet_pkgdmg_installed_#{name}", "w") do |t|
      t.print "name: '#{name}'\n"
      t.print "source: '#{orig_source}'\n"
    end
  end

  def self.installpkgdmg(source, name)
    unless Puppet::Util::HttpProxy.no_proxy?(source)
      http_proxy_host = Puppet::Util::HttpProxy.http_proxy_host
      http_proxy_port = Puppet::Util::HttpProxy.http_proxy_port
    end

    unless source =~ /\.dmg$/i || source =~ /\.pkg$/i
      raise Puppet::Error.new("Mac OS X PKG DMG's must specify a source string ending in .dmg or flat .pkg file")
    end
    require 'open-uri' # Dead code; this is never used. The File.open call 20-ish lines south of here used to be Kernel.open but changed in '09. -NF
    cached_source = source
    tmpdir = Dir.mktmpdir
    ext = /(\.dmg|\.pkg)$/i.match(source)[0]
    begin
      if %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://} =~ cached_source
        cached_source = File.join(tmpdir, "#{name}#{ext}")
        args = [ "-o", cached_source, "-C", "-", "-L", "-s", "--fail", "--url", source ]
        if http_proxy_host and http_proxy_port
          args << "--proxy" << "#{http_proxy_host}:#{http_proxy_port}"
        elsif http_proxy_host and not http_proxy_port
          args << "--proxy" << http_proxy_host
        end
      begin
        curl *args
          Puppet.debug "Success: curl transferred [#{name}] (via: curl #{args.join(" ")})"
        rescue Puppet::ExecutionFailure
          Puppet.debug "curl #{args.join(" ")} did not transfer [#{name}].  Falling back to local file." # This used to fall back to open-uri. -NF
          cached_source = source
        end
      end

      if source =~ /\.dmg$/i
        # If you fix this to use open-uri again, you must update the docs above. -NF
        File.open(cached_source) do |dmg|
          xml_str = hdiutil "mount", "-plist", "-nobrowse", "-readonly", "-noidme", "-mountrandom", "/tmp", dmg.path
          hdiutil_info = Puppet::Util::Plist.parse_plist(xml_str)
          raise Puppet::Error.new("No disk entities returned by mount at #{dmg.path}") unless hdiutil_info.has_key?("system-entities")
          mounts = hdiutil_info["system-entities"].collect { |entity|
            entity["mount-point"]
          }.compact
          begin
            mounts.each do |mountpoint|
              Dir.entries(mountpoint).select { |f|
                f =~ /\.m{0,1}pkg$/i
              }.each do |pkg|
                installpkg("#{mountpoint}/#{pkg}", name, source)
              end
            end
          ensure
            mounts.each do |mountpoint|
              hdiutil "eject", mountpoint
            end
          end
        end
      else
        installpkg(cached_source, name, source)
      end
    ensure
      FileUtils.remove_entry_secure(tmpdir, true)
    end
  end

  def query
    if Puppet::FileSystem.exist?("/var/db/.puppet_pkgdmg_installed_#{@resource[:name]}")
      Puppet.debug "/var/db/.puppet_pkgdmg_installed_#{@resource[:name]} found"
      return {:name => @resource[:name], :ensure => :present}
    else
      return nil
    end
  end

  def install
    source = nil
    unless source = @resource[:source]
      raise Puppet::Error.new("Mac OS X PKG DMG's must specify a package source.")
    end
    unless name = @resource[:name]
      raise Puppet::Error.new("Mac OS X PKG DMG's must specify a package name.")
    end
    self.class.installpkgdmg(source,name)
  end
end
