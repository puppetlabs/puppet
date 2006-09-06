# OS X Packaging sucks.  We can install packages, but that's about it.
Puppet::Type.type(:package).provide :apple do
    desc "Package management based on OS X's builtin packaging system.  This is
        essentially the simplest and least functional package system in existence --
        it only supports installation; no deletion or upgrades."

    confine :exists => "/Library/Receipts"
    commands :installer => "/usr/sbin/installer"

    defaultfor :operatingsystem => :darwin

    def self.listbyname
        Dir.entries("/Library/Receipts").find { |f|
            f =~ /\.pkg$/
        }.collect { |f|
            name = f.sub(/\.pkg/, '')
            yield name if block_given?

            name
        }
    end

    def self.list
        listbyname.collect do |name|
            Puppet.type(:package).installedpkg(
                :name => name,
                :provider => :apple,
                :ensure => :installed
            )
        end
    end

    def query
        if FileTest.exists?("/Library/Receipts/#{@model[:name]}.pkg")
            return {:name => @model[:name], :ensure => :present}
        else
            return nil
        end
    end

    def install
        source = nil
        unless source = @model[:source]
            self.fail "Mac OS X packages must specify a package source"
        end

        installer "-pkg #{source} -target /"
    end
end

# $Id$
