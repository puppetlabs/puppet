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

Puppet::Type.type(:package).provide :pkgdmg, :parent => Puppet::Provider::Package do
    desc "Package management based on Apple's Installer.app and DiskUtility.app
    
Author: Jeff McCune <jeff@northstarlabs.net>

Please direct questions about this provider to the puppet-users mailing list.

This package works by checking the contents of a DMG image for Apple pkg or
mpkg files. Any number of pkg or mpkg files may exist in the root directory of
the DMG file system. Sub directories are not checked for packages.

This provider always assumes the label (formerly called 'name') attribute
declared in the manifest will always exactly match the file name (without
path) of the DMG file itself. Therefore, if you want to install packages in
'Foobar.pkg.dmg' you must explicitly specify the label:

 package { Foobar.pkg.dmg: ensure => installed, provider => pkgdmg }

Only the dmg file name itself is used when puppet determines if the packages
contained within are currently installed. For example, if a package resource
named 'Foobar.pkg.dmg' is named for installation and contains multiple
packages, this provider will install all packages in the root directory of
this file system, then create a small cookie for the whole bundle, located at
/var/db/.puppet_pkgdmg_installed_Foobar.pkg.dmg

As a result, if you change the contents of the DMG file in any way, Puppet
will not update or re-install the packages contained within unless you change
the file name of the DMG wrapper itself. Therefore, if you use this provider,
I recommend you name the DMG wrapper files in a manner that lends itself to
incremental version changes. I include some version or date string in the DMG
name, like so:

 Firefox-2.0.0.3-1.pkg.dmg

If I realize I've mis-packaged this DMG, then I have the option to increment
the package version, yielding Firefox-2.0.0.3-2.pkg.dmg.

This provider allows you to host DMG files within an FTP or HTTP server. This
is primarily how the author provider distributes software. Any URL mechanism
curl or Ruby's open-uri module supports is supported by this provider. Curl
supported URL's yield much faster data throughput than open-uri, so I
recommend HTTP, HTTPS, or FTP for source package repositories.

Because the provider assumes packages will be transfered via CURL, a two stage
process occurs. First, if a URL is detected, curl is invoked to transfer the
file into a temporary directory. If no URL is present, the provider skips
straight to step 2. In step two, the source file is mounted, then packages
installed, and finally the DMG file is removed.

WARNING: Because I assume files will be downloaded to /tmp, the current
implementation attempts to delete DMG files if you install directly from the
file system and not via a URL method.

If this is a problem for you, please patch the code, or bug Jeff to fix this.

Example usage:

package { Thunderbird-2.0.0.4-1.pkg.dmg:
  provider => pkgdmg, ensure => present
  source => 'http://0.0.0.0:8000/packages/Thunderbird-2.0.0.4-1.pkg.dmg',
}
"
  

    confine :exists => "/Library/Receipts"
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
            self.fail "Mac OS X PKG DMG's must specificy a source string ending in .dmg"
        end
        require 'open-uri'
        require 'puppet/util/plist'
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
                xml_str = hdiutil "mount", "-plist", "-nobrowse", "-readonly", "-mountrandom", "-noidme", "/tmp", dmg.path
                ptable = Plist::parse_xml xml_str
                # JJM Filter out all mount-paths into a single array, discard the rest.
                mounts = ptable['system-entities'].collect { |entity|
                    entity['mount-point']
                }.select { |mountloc|; mountloc }
                begin
                    mounts.each do |fspath|
                        Dir.entries(fspath).select { |f|
                            f =~ /\.m{0,1}pkg$/i
                            }.each do |pkg|
                                installpkg("#{fspath}/#{pkg}", name, source)
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
        if FileTest.exists?("/var/db/.puppet_pkgdmg_installed_#{@resource[:name]}")
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

# $Id$
