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

        if @resource[:source] =~ /\/$/
            if @resource[:source] =~ /^(ftp|https?):/
                withenv :PACKAGESITE => @resource[:source] do
                    pkgadd "-r", @resource[:name]
                end
            else
                withenv :PKG_PATH => @resource[:source] do
                    pkgadd @resource[:name]
                end
            end
        else
            if @resource[:source]
                Puppet.warning "source is defined but does not have trailing slash, ignoring %s" % @resource[:source]
            end
            pkgadd "-r", @resource[:name]
        end
    end

    def query
        self.class.instances.each do |provider|
            if provider.name == @resource.name
                return provider.properties
            end
        end
        return nil
    end

    def uninstall
        pkgdelete "%s-%s" % [@resource[:name], @resource.should(:ensure)]
    end
end

