require 'Paludis'
require 'puppet/provider/package'

Puppet::Type.type(:package).provide :paludis, :parent => Puppet::Provider::Package do
    desc "Provides packaging support for Gentoo's alternative package system called paludis."

    has_feature :versionable

    commands :paludis => '/usr/bin/paludis'

    #defaultfor :operatingsystem => :gentoo

    Paludis::Log.instance.log_level = Paludis::LogLevel::Warning
    @env = Paludis::EnvironmentMaker.instance.make_from_spec('')

    def get_paludis_instance
        return Paludis::EnvironmentMaker.instance.make_from_spec('')
    end

    def package_name
        pkg = nil
        begin
            pkg = @env.package_database.fetch_unique_qualified_package_name(@resource[:name])
        rescue Paludis::NoSuchPackageError
            raise Puppet::PackageError.new('Package does not exists')
        rescue Paludis::AmbiguousPackageNameError => e
            if(!@resource[:category] && !@resource[:category].empty?)
                pkg = Paludis::PackageDepSpec.new('%s/%s' % [:category, :name].collect{ |key| @resource[key]}, Paludis::PackageDepSpecParseMode::Permissive)
                if(@env.package_database.query(Paludis::Query::Package.new(pkg), Paludis::QueryOrder::Whatever).empty?)
                    raise Puppet::PackageError.new("No package names '#{@resource[:name]}' in category '#{@resource[:category]}'")
                end
            else
                raise Puppet::PackageError.new(e.message + "\nPlease specifiy a category")
            end
        end

        if(!pkg.nil? && pkg.kind_of?(String))
            pkg = Paludis::QualifiedPackageName.new(pkg)
        end

        return pkg
    end

    def self.instances
        packages = Array.new
        @env.package_database.query(Paludis::Query::RepositoryHasInstalledInterface.new, Paludis::QueryOrder::Whatever).each { |p|
            next if(p.name.category == 'virtual')
            pkg = Paludis::PackageDepSpec.new(p.name, Paludis::PackageDepSpecParseMode::Permissive)
            package = {
                :name => p.name.package,
                :ensure => p.version.to_s,
                :category => p.name.category,
                :version_available => @env.package_database.query(Paludis::Query::RepositoryHasInstallableInterface.new & Paludis::Query::NotMasked.new & Paludis::Query::Package.new(p.name), Paludis::QueryOrder::GroupBySlot).last.version.to_s
            }
            packages << new(package)
        }
        return packages
    end

    #def initialize(resource = nil)
    #    super(resource)
    #end

    def install
        should = @resource.should(:ensure)
        name = package_name
        unless should == :present or should == :latest
            # We must install a specific version
            name = "=%s-%s" % [name, should]
        end
        paludis '-i', name
    end

    def update
        self.install
    end

    def query
        @env = self.get_paludis_instance
        pkg = package_name
        package = {
            :name => pkg.package,
            :category => pkg.category,
            :ensure => :absent,
            :version_available => :absent
        }
        if(p = @env.package_database.query(Paludis::Query::Package.new(pkg) & Paludis::Query::RepositoryHasInstalledInterface.new, Paludis::QueryOrder::GroupBySlot))
           package[:ensure] = (p.length > 0 ? p.last.version.to_s : :absent)
        end
        if(p = @env.package_database.query(Paludis::Query::RepositoryHasInstallableInterface.new & Paludis::Query::NotMasked.new & Paludis::Query::Package.new(pkg), Paludis::QueryOrder::GroupBySlot))
           package[:version_available] = (p.length > 0 ? p.last.version.to_s : :absent)
        end
        return package
    end

    def uninstall
        @env = self.get_paludis_instance
        params = ['-u', package_name].compact
        paludis *params
    end

    def latest
        return self.query[:version_available]
    end
end

