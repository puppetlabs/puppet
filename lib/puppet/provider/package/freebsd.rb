Puppet::Type.type(:package).provide :freebsd, :parent => :openbsd do
    desc "The specific form of package management on FreeBSD.  This is an
        extremely quirky packaging system, in that it freely mixes between
        ports and packages.  Apparently all of the tools are written in Ruby,
        so there are plans to rewrite this support to directly use those
        libraries."

    commands :pkginfo => "/usr/sbin/pkg_info",
             :pkgadd => "/usr/sbin/pkg_add",
             :pkgdelete => "/usr/sbin/pkg_delete"

    def self.listcmd
        command(:pkginfo)
    end

    def install
        should = @model.should(:ensure)

        if @model[:source]
            return super
        end

        pkgadd " -r " + @model[:name]
    end

    def query
        self.class.list

        if @model.is(:ensure)
            return :listed
        else
            return nil
        end
    end

    def uninstall
        pkgdelete "%s-%s" % [@model[:name], @model.should(:ensure)]
    end
end

# $Id$
