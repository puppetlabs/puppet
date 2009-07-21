#
# pkgdmg.rb
#
# Install Installer.app packages wrapped up inside a DMG image file.
#
# Copyright (C) 2007 Jeff McCune Jeff McCune <jeff@northstarlabs.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation (version 2 of the License)
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston MA  02110-1301 USA
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
require 'facter/util/plist'

Puppet::Type.type(:package).provide :pkgdmg, :parent => Puppet::Provider::Package do
    desc "Package management based on Apple's Installer.app and DiskUtility.app.  This package works by checking the contents of a DMG image for Apple pkg or mpkg files. Any number of pkg or mpkg files may exist in the root directory of the DMG file system. Sub directories are not checked for packages.  See `the wiki docs </trac/puppet/wiki/DmgPackages>` for more detail."
    
    confine :operatingsystem => :darwin
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
            new(
                :name => name,
                :provider => :pkgdmg,
                :ensure => :installed
            )
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
        unless source =~ /\.dmg$/i
            raise Puppet::Error.new("Mac OS X PKG DMG's must specificy a source string ending in .dmg")
        end
        require 'open-uri'
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
            File.open(cached_source) do |dmg|
                xml_str = hdiutil "mount", "-plist", "-nobrowse", "-readonly", "-noidme", "-mountrandom", "/tmp", dmg.path
                hdiutil_info = Plist::parse_xml(xml_str)
                unless hdiutil_info.has_key?("system-entities")
                    raise Puppet::Error.new("No disk entities returned by mount at %s" % dmg.path)
                end
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
        ensure
            # JJM Remove the file if open-uri didn't already do so.
            File.unlink(cached_source) if File.exist?(cached_source)
        end
    end

    def query
        if FileTest.exists?("/var/db/.puppet_pkgdmg_installed_#{@resource[:name]}")
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

