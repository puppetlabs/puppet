Puppet::Type.type(:package).provide :portage do
    desc "Provides packaging support for Gentoo's portage system."

    commands :emerge => "/usr/bin/emerge", :eix => "/usr/bin/eix"

    defaultfor :operatingsystem => :gentoo

    def self.format
        "{installedversions}<category> <name> [<installedversions>] [<best>] <homepage> <description>{}"
    end

    def self.list
        search_format = /(\S+) (\S+) \[(.*)\] \[([^\s:]*)(:\S*)?\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available, :slot, :vendor, :description]

        begin
            search_output = eix "--format", format()

            packages = []
            search_output.each do |search_result|
                match = search_format.match( search_result )

                if match
                    package = {}
                    result_fields.zip(match.captures) { |field, value|
                        package[field] = value unless !value or value.empty?
                    }
                    package[:provider] = :portage
                    package[:ensure] = package[:ensure].split.last

                    packages.push(Puppet.type(:package).installedpkg(package))
                end
            end

            return packages
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def install
        should = @model.should(:ensure)
        name = package_name
        unless should == :present or should == :latest
            # We must install a specific version
            name = "=%s-%s" % [name, should]
        end
        emerge name
    end

    # The common package name format.
    def package_name
        "%s/%s" % [@model[:category], @model[:name]]
    end

    def uninstall
        emerge "--unmerge", package_name
    end

    def update
        self.install
    end

    def query
        search_format = /(\S+) (\S+) \[(.*)\] \[([^\s:]*)(:\S*)?\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available, :slot, :vendor, :description]

        search_field = @model[:name].include?( '/' ) ? "--category-name" : "--name"
        format = "<category> <name> [<installedversions>] [<best>] <homepage> <description>"

        begin
            search_output = eix "-format", format, "--exact", search_field, @model[:name]

            packages = []
            search_output.each do |search_result|
                match = search_format.match( search_result )

                if( match )
                    package = {}
                    result_fields.zip( match.captures ) { |field, value| package[field] = value unless !value or value.empty? }
                    if package[:ensure]
                        package[:ensure] = package[:ensure].split.last
                    else
                        package[:ensure] = :absent
                    end
                    packages << package
                end
            end

            case packages.size
                when 0
                    raise Puppet::PackageError.new("No package found with the specified name [#{@model[:name]}]")
                when 1
                    return packages[0]
                else
                    raise Puppet::PackageError.new("More than one package with the specified name [#{@model[:name]}], please use category/name to disambiguate")
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def latest
        return self.query[:version_available]
    end

    def versionable?
        true
    end
end

# $Id$
