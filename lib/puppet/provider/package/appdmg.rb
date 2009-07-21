# Jeff McCune <mccune.jeff@gmail.com>
# Changed to app.dmg by: Udo Waechter <root@zoide.net>
# Mac OS X Package Installer which handles application (.app)
# bundles inside an Apple Disk Image.
#
# Motivation: DMG files provide a true HFS file system
# and are easier to manage.
#
# Note: the 'apple' Provider checks for the package name
# in /L/Receipts.  Since we possibly install multiple apps's from
# a single source, we treat the source .app.dmg file as the package name.
# As a result, we store installed .app.dmg file names
# in /var/db/.puppet_appdmg_installed_<name>

require 'puppet/provider/package'
Puppet::Type.type(:package).provide(:appdmg, :parent => Puppet::Provider::Package) do
    desc "Package management which copies application bundles to a target."

    confine :operatingsystem => :darwin
    
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
      File.open("/var/db/.puppet_appdmg_installed_#{name}", "w") do |t|
          t.print "name: '#{name}'\n"
          t.print "source: '#{orig_source}'\n"
      end
    end

    def self.installpkgdmg(source, name)
        unless source =~ /\.dmg$/i
            self.fail "Mac OS X PKG DMG's must specificy a source string ending in .dmg"
        end
        require 'open-uri'
        require 'facter/util/plist'
        cached_source = source
        if %r{\A[A-Za-z][A-Za-z0-9+\-\.]*://} =~ cached_source
            cached_source = "/tmp/#{name}"
            begin
                curl "-o", cached_source, "-C", "-", "-k", "-s", "--url", source
                Puppet.debug "Success: curl transfered [#{name}]"
            rescue Puppet::ExecutionFailure
                Puppet.debug "curl did not transfer [#{name}].  Falling back to slower open-uri transfer methods."
                cached_source = source
            end
        end

        begin
            open(cached_source) do |dmg|
                xml_str = hdiutil "mount", "-plist", "-nobrowse", "-readonly", "-mountrandom", "/tmp", dmg.path
                    ptable = Plist::parse_xml xml_str
                    # JJM Filter out all mount-paths into a single array, discard the rest.
                    mounts = ptable['system-entities'].collect { |entity|
                        entity['mount-point']
                    }.select { |mountloc|; mountloc }
                    begin
                        mounts.each do |fspath|
                            Dir.entries(fspath).select { |f|
                                f =~ /\.app$/i
                            }.each do |pkg|
                                installapp("#{fspath}/#{pkg}", name, source)
                            end
                        end # mounts.each do
                    ensure
                        hdiutil "eject", mounts[0]
                    end # begin
            end # open() do
        ensure
            # JJM Remove the file if open-uri didn't already do so.
            File.unlink(cached_source) if File.exist?(cached_source)
        end # begin
    end # def self.installpkgdmg

    def query
        if FileTest.exists?("/var/db/.puppet_appdmg_installed_#{@resource[:name]}")
            return {:name => @resource[:name], :ensure => :present}
        else
            return nil
        end
    end

    def install
        source = nil
        unless source = @resource[:source]
            self.fail "Mac OS X PKG DMG's must specify a package source."
        end
        unless name = @resource[:name]
            self.fail "Mac OS X PKG DMG's must specify a package name."
        end
        self.class.installpkgdmg(source,name)
    end
end

