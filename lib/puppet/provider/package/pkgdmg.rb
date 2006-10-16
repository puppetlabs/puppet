# Jeff McCune <mccune.jeff@gmail.com>
# Mac OS X Package Installer which handles .pkg and .mpkg
# bundles inside an Apple Disk Image.
#
# Motivation: DMG files provide a true HFS file system
# and are easier to manage and .pkg bundles.
#
# Note: the 'apple' Provider checks for the package name
# in /L/Receipts.  Since we install multiple pkg's from a single
# source, we treat the source .pkg.dmg file as the package name.
# As a result, we store installed .pkg.dmg file names
# in /var/db/.puppet_pkgdmg_installed_<name>

# require 'ruby-debug'
# Debugger.start

Puppet::Type.type(:package).provide :pkgdmg do
    desc "Package management based on Apple's Installer.app and DiskUtility.app"

    confine :exists => "/Library/Receipts"
    commands :installer => "/usr/sbin/installer"
    commands :hdiutil => "/usr/bin/hdiutil"

    # JJM We store a cookie for each installed .pkg.dmg in /var/db
    def self.listbyname
        Dir.entries("/var/db").find_all { |f|
            f =~ /^\.puppet_pkgdmg_installed_/
        }.collect { |f|
            name = f.sub(/^\.puppet_pkgdmg_installed_/, '')
            yield name if block_given?

            name
        }
    end

    def self.list
        listbyname.collect do |name|
            Puppet.type(:package).installedpkg(
                :name => name,
                :provider => :pkgdmg,
                :ensure => :installed
            )
        end
    end

    def self.installpkg(source, name, orig_source)
      installer "-pkg '#{source}' -target /"
      File.open("/var/db/.puppet_pkgdmg_installed_#{name}", "w") do |t|
          t.print "name: '#{name}'\n"
          t.print "source: '#{orig_source}'\n"
      end      
    end
    
    def self.installpkgdmg(source, name)
        unless source =~ /\.dmg$/i
            self.fail "Mac OS X PKG DMG's must specificy a source string ending in .dmg"
        end
        require 'open-uri'
        require 'puppet/util/plist'
        open(source) do |dmg|
            cmd = "/usr/bin/hdiutil mount -plist -nobrowse -readonly -mountrandom /tmp #{dmg.path}"
            IO.popen(cmd) do |pipe|
                xml_str = pipe.read
                ptable = Plist::parse_xml xml_str
                # JJM Filter out all mount-paths into a single array, discard the rest.
                mounts = ptable['system-entities'].collect { |entity|
                    entity['mount-point']
                }.select { |mountloc|; mountloc }
                mounts.each do |fspath|
                    Dir.entries(fspath).select { |f|
                        f =~ /\.m{0,1}pkg$/i
                    }.each { |pkg|
                        installpkg ("#{fspath}/#{pkg}", name, source)
                    }
                end
            hdiutil "eject '#{mounts[0]}'"
            end
        end
    end

    def query
        if FileTest.exists?("/var/db/.puppet_pkgdmg_installed_#{@model[:name]}")
            return {:name => @model[:name], :ensure => :present}
        else
            return nil
        end
    end

    def install
        source = nil
        unless source = @model[:source]
            self.fail "Mac OS X PKG DMG's must specify a package source."
        end
        unless name = @model[:name]
            self.fail "Mac OS X PKG DMG's must specify a package name."
        end
        self.class.installpkgdmg(source,name)
    end
end

# $Id$
