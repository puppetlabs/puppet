Puppet::Type.type(:package).provide :freebsd, :parent => :openbsd do
    desc "The specific form of package management on FreeBSD.  This is an
        extremely quirky packaging system, in that it freely mixes between
        ports and packages.  Apparently all of the tools are written in Ruby,
        so there are plans to rewrite this support to directly use those
        libraries."

    commands :pkginfo => "/usr/sbin/pkg_info",
             :pkgadd => "/usr/sbin/pkg_add",
             :pkgdelete => "/usr/sbin/pkg_delete"
    
    confine :operatingsystem => :freebsd

    def self.listcmd
        command(:pkginfo)
    end

    def install
        should = @resource.should(:ensure)

        if @resource[:source]
            return super
        end

        pkgadd "-r", @resource[:name]
    end

    def query
        self.class.list

        if @resource.is(:ensure)
            return :listed
        else
            return nil
        end
    end

    def uninstall
        pkgdelete "%s-%s" % [@resource[:name], @resource.should(:ensure)]
    end
end

# $Id$
