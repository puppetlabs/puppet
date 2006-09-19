Puppet::Type.type(:package).provide :portage do
    desc "Provides packaging support for Gentoo's portage system."

    commands :emerge => "/usr/bin/emerge", :eix => "/usr/bin/eix"

    defaultfor :operatingsystem => :gentoo

    def self.list
        search_format = /(\S+) (\S+) \[(.*)\] \[(\S*)\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available,
                :vendor, :description]
        command = "#{command(:eix)} --format \"{installedversions}<category> <name> [<installedversions>] [<best>] <homepage> <description>{}\""

        begin
            search_output = execute( command )

            packages = []
            search_output.each do |search_result|
                match = search_format.match( search_result )

                if( match )
                    package = {}
                    result_fields.zip( match.captures ) { |field, value| package[field] = value unless value.empty? }
                    package[:provider] = :portage
                    package[:ensure] = package[:ensure].split.last

                    packages.push( Puppet.type(:package).installedpkg(package) )
                end
            end

            return packages
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def install
        if @model.should( :ensure ) == :present || @model.should( :ensure ) == :latest
            package_name = "#{@model[:category]}/#{@model[:name]}"
        else
            # We must install a specific version
            package_name = "=#{@model[:category]}/#{@model[:name]}-#{@model.should( :ensure )}"
        end
        command = "EMERGE_DEFAULT_OPTS=\"\" #{command(:emerge)} #{package_name}"

        output = execute( command )
    end

    def uninstall
        package_name = "#{@model[:category]}/#{@model[:name]}"
        command ="EMERGE_DEFAULT_OPTS=\"\" #{command(:emerge)} --unmerge #{package_name}"
        begin
            output = execute( command )
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def update
        self.install
    end

    def query
        search_format = /(\S+) (\S+) \[(.*)\] \[(\S*)\] ([\S]*) (.*)/
        result_fields = [:category, :name, :ensure, :version_available, :vendor, :description]

        search_field = @model[:name].include?( '/' ) ? "--category-name" : "--name"
        command = "#{command(:eix)} --format \"<category> <name> [<installedversions>] [<best>] <homepage> <description>\" --exact #{search_field} #{@model[:name]}"

        begin
            search_output = execute( command )

            packages = []
            search_output.each do |search_result|
                match = search_format.match( search_result )

                if( match )
                    package = {}
                    result_fields.zip( match.captures ) { |field, value| package[field] = value unless value.empty? }
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
                    raise Puppet::PackageError.new( "No package found with the specified name [#{@model[:name]}]" )
                when 1
                    return packages[0]
                else
                    raise Puppet::PackageError.new( "More than one package with the specified name [#{@model[:name]}], please use category/name to disambiguate" )
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
