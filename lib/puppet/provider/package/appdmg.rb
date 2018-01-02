# Jeff McCune <mccune.jeff@gmail.com>
# Changed to app.dmg by: Udo Waechter <root@zoide.net>
# Mac OS X Package Installer which handles application (.app)
# bundles inside an Apple Disk Image.
#
# Motivation: DMG files provide a true HFS file system
# and are easier to manage.
#
# Note: the 'apple' Provider checks for the package name
# in /L/Receipts.  Since we possibly install multiple apps from
# a single source, we treat the source .app.dmg file as the package name.
# As a result, we store installed .app.dmg file names
# in /var/db/.puppet_appdmg_installed_<name>

require 'puppet/provider/package'
require 'puppet/util/plist' if Puppet.features.cfpropertylist?
Puppet::Type.type(:package).provide(:appdmg, :parent => Puppet::Provider::Package) do
  desc "Package management which copies application bundles to a target."

  confine :operatingsystem => :darwin
  confine :feature         => :cfpropertylist

  commands :hdiutil => "/usr/bin/hdiutil"
  commands :curl => "/usr/bin/curl"
  commands :ditto => "/usr/bin/ditto"

  # JJM We store a cookie for each installed .app.dmg in /var/db
  def self.instances_by_name
    Dir.entries("/var/db").find_all { |f|
      f =~ /^\.puppet_appdmg_installed_/
    }.collect do |f|
      name = f.sub(/^\.puppet_appdmg_installed_/, '')
      yield name if block_given?
      name
    end
  end

  def self.instances
    instances_by_name.collect do |name|
      new(:name => name, :provider => :appdmg, :ensure => :installed)
    end
  end

  def self.installapp(source, name, orig_source)
    appname = File.basename(source);
    ditto "--rsrc", source, "/Applications/#{appname}"
    Puppet::FileSystem.open("/var/db/.puppet_appdmg_installed_#{name}", nil, "w:UTF-8") do |t|
      t.print "name: '#{name}'\n"
      t.print "source: '#{orig_source}'\n"
    end
  end

  def self.installpkgdmg(source, name)
    require 'open-uri'
    cached_source = source
    tmpdir = Dir.mktmpdir
    begin
      if %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://} =~ cached_source
        cached_source = File.join(tmpdir, name)
        begin
          curl "-o", cached_source, "-C", "-", "-L", "-s", "--url", source
          Puppet.debug "Success: curl transferred [#{name}]"
        rescue Puppet::ExecutionFailure
          Puppet.debug "curl did not transfer [#{name}].  Falling back to slower open-uri transfer methods."
          cached_source = source
        end
      end

      open(cached_source) do |dmg|
        xml_str = hdiutil "mount", "-plist", "-nobrowse", "-readonly", "-mountrandom", "/tmp", dmg.path
          ptable = Puppet::Util::Plist::parse_plist(xml_str)
          # JJM Filter out all mount-paths into a single array, discard the rest.
          mounts = ptable['system-entities'].collect { |entity|
            entity['mount-point']
          }.select { |mountloc|; mountloc }
          begin
            found_app = false
            mounts.each do |fspath|
              Dir.entries(fspath).select { |f|
                f =~ /\.app$/i
              }.each do |pkg|
                found_app = true
                installapp("#{fspath}/#{pkg}", name, source)
              end
            end
            Puppet.debug "Unable to find .app in .appdmg. #{name} will not be installed." if !found_app
          ensure
            hdiutil "eject", mounts[0]
          end
      end
    ensure
      FileUtils.remove_entry_secure(tmpdir, true)
    end
  end

  def query
    Puppet::FileSystem.exist?("/var/db/.puppet_appdmg_installed_#{@resource[:name]}") ? {:name => @resource[:name], :ensure => :present} : nil
  end

  def install
    unless source = @resource[:source]
      self.fail _("Mac OS X PKG DMGs must specify a package source.")
    end
    unless name = @resource[:name]
      self.fail _("Mac OS X PKG DMGs must specify a package name.")
    end
    self.class.installpkgdmg(source,name)
  end
end
