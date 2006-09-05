Puppet::Type.type(:package).provide :freebsd, :parent => :openbsd do
    desc "The specific form of package management on FreeBSD.  This is an
        extremely quirky packaging system, in that it freely mixes between
        ports and packages.  Apparently all of the tools are written in Ruby,
        so there are plans to rewrite this support to directly use those
        libraries."

    commands :info => "/usr/sbin/pkg_info",
             :add => "/usr/sbin/pkg_add",
             :delete => "/usr/sbin/pkg_delete"

    def self.listcmd
        command(:info)
    end

    def install
        should = @model[:ensure]

        if @model[:source]
            return super
        end

        cmd = command(:add) + " -r " + @model[:name]

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
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
        cmd = "#{command(:delete)} %s-%s" % [@model[:name], @model[:ensure]]
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::PackageError.new(output)
        end
    end
end

# $Id$
