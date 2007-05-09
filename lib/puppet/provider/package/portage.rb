Puppet::Type.type(:package).provide :portage do
    desc "Provides packaging support for Gentoo's portage system."

    commands :emerge => "/usr/bin/emerge", :eix => "/usr/bin/eix"

    defaultfor :operatingsystem => :gentoo

    def self.list
        result_format = /(\S+) (\S+) \[(.*)\] \[[^0-9]*([^\s:]*)(:\S*)?\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available, :slot, :vendor, :description]

        search_format = "{installedversionsshort}<category> <name> [<installedversionsshort>] [<best>] <homepage> <description>{}"

        begin
            search_output = eix "--nocolor", "--format", search_format

            packages = []
            search_output.each do |search_result|
                match = result_format.match( search_result )

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
        should = @resource.should(:ensure)
        name = package_name
        unless should == :present or should == :latest
            # We must install a specific version
            name = "=%s-%s" % [name, should]
        end
        emerge name
    end

    # The common package name format.
    def package_name
        "%s/%s" % [@resource[:category], @resource[:name]]
    end

    def uninstall
        emerge "--unmerge", package_name
    end

    def update
        self.install
    end

    def query
        result_format = /(\S+) (\S+) \[(.*)\] \[[^0-9]*([^\s:]*)(:\S*)?\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available, :slot, :vendor, :description]

        search_field = @resource[:category] ? "--category-name" : "--name"
        search_value = @resource[:category] ? package_name : @resource[:name]
        search_format = "<category> <name> [<installedversionsshort>] [<best>] <homepage> <description>"

        begin
            search_output = eix "--nocolor", "--format", search_format, "--exact", search_field, search_value

            packages = []
            search_output.each do |search_result|
                match = result_format.match( search_result )

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
		    not_found_value = "%s/%s" % [@resource[:category] ? @resource[:category] : "<unspecified category>", @resource[:name]]
                    raise Puppet::PackageError.new("No package found with the specified name [#{not_found_value}]")
                when 1
                    return packages[0]
                else
                    raise Puppet::PackageError.new("More than one package with the specified name [#{search_value}], please use the category parameter to disambiguate")
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
