require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide :aix, :parent => Puppet::Provider::Package do
    desc "Installation from AIX Software directory"

    # The commands we are using on an AIX box are installed standard
    # (except nimclient) nimclient needs the bos.sysmgt.nim.client fileset.
    commands    :lslpp => "/usr/bin/lslpp",
                :installp => "/usr/sbin/installp"

    # AIX supports versionable packages with and without a NIM server
    has_feature :versionable

    confine  :operatingsystem => [ :aix ]
    defaultfor :operatingsystem => :aix

    attr_accessor   :latest_info

    def self.srclistcmd(source)
        return [ command(:installp), "-L", "-d", source ]
    end

    def self.prefetch(packages)
        if Process.euid != 0
            raise Puppet::Error, "The aix provider can only be used by root"
        end

        return unless packages.detect { |name, package| package.should(:ensure) == :latest }

        sources = packages.collect { |name, package| package[:source] }.uniq

        updates = {}
        sources.each do |source|
            execute(self.srclistcmd(source)).each do |line|
                if line =~ /^[^#][^:]*:([^:]*):([^:]*)/
                    current = {}
                    current[:name]    = $1
                    current[:version] = $2
                    current[:source]  = source

                    if updates.key?(current[:name])
                        previous = updates[current[:name]]

                        unless Puppet::Util::Package.versioncmp(previous[:version], current[:version]) == 1
                            updates[ current[:name] ] = current 
                        end

                    else
                        updates[current[:name]] = current
                    end
                end
            end
        end

        packages.each do |name, package|
            if info = updates[package[:name]]
                package.provider.latest_info = info[0]
            end
        end
    end

    def uninstall
        # Automatically process dependencies when installing/uninstalling
        # with the -g option to installp.
        installp "-gu", @resource[:name]
    end

    def install(useversion = true)
        unless source = @resource[:source]
            self.fail "A directory is required which will be used to find packages"
        end

        pkg = @resource[:name]

        if (! @resource.should(:ensure).is_a? Symbol) and useversion
            pkg << " #{@resource.should(:ensure)}"
        end

        installp "-acgwXY", "-d", source, pkg
    end

    def self.pkglist(hash = {})
        cmd = [command(:lslpp), "-qLc"]

        if name = hash[:pkgname]
            cmd << name
        end

        begin
            list = execute(cmd).scan(/^[^#][^:]*:([^:]*):([^:]*)/).collect { |n,e|
                { :name => n, :ensure => e, :provider => self.name }
            }
        rescue Puppet::ExecutionFailure => detail
            if hash[:pkgname]
                return nil
            else
                raise Puppet::Error, "Could not list installed Packages: %s" % detail
            end
        end

        if hash[:pkgname]
            return list.shift
        else
            return list
        end
    end

    def self.instances
        pkglist.collect do |hash|
            new(hash)
        end
    end

    def latest
        upd = latest_info

        unless upd.nil?
            return "#{upd[:version]}"
        else
            if properties[:ensure] == :absent
                raise Puppet::DevError, "Tried to get latest on a missing package"
            end

            return properties[:ensure]
        end
    end

    def query
        return self.class.pkglist(:pkgname => @resource[:name])
    end

    def update
        self.install(false)
    end
end
