Puppet::Type.type(:package).provide :portage do
    desc "Provides packaging support for Gentoo's portage system."

    commands :emerge => "emerge", :eix => "eix"

    defaultfor :operatingsystem => :gentoo

    def self.list
        search_format = /(\S+) (\S+) \[(.*)\] \[(\S*)\] ([\S]*) (.*)/
        result_fields = [:category, :name, :version, :version_available,
                :vendor, :description]
        command = "#{command(:eix)} --format \"{<installedversions>}<category> <name> [<installedversions>] [<best>] <homepage> <description>{}\""

        begin
            search_output = execute( command )

            packages = []
            search_output.each do |search_result|
                match = search_format.match( search_result )

                if( match )
                    package = {:ensure => :present}
                    result_fields.zip( match.captures ) { |field, value| package[field] = value }
                    if self.is_a? Puppet::Type and type = @model[:type]
                        package[:type] = type
                    elsif self.is_a? Module and self.respond_to? :name
                        package[:type] = self.name
                    else
                        raise Puppet::DevError, "Cannot determine package type"
                    end
                    if package[:version]
                        package[:version] = package[:version].split.last
                    end

                    packages.push( Puppet.type(:package).installedpkg(package) )
                end
            end

            return packages
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def install
        if @model[:version]
            # We must install a specific version
            package_name = "=#{@model[:name]}-#{@model[:version]}"
        else
            package_name = @model[:name]
        end
        command = "EMERGE_DEFAULT_OPTS=\"\" #{command(:emerge)} #{package_name}"
        begin
            output = execute( command )
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(detail)
        end
    end

    def uninstall
        if @model[:version]
            # We must uninstall a specific version
            package_name = "=#{@model[:name]}-#{@model[:version]}"
        else
            package_name = @model[:name]
        end
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
        result_fields = [:category, :name, :version, :version_available, :vendor, :description]

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
                    package[:ensure] = package[:version] ? :present : :absent
                    package[:version] = package[:version].split.last if package[:version]
                    packages << package
                end
            end

            case packages.size
                when 0
                    return nil
                when 1
                    return packages[0]
                else
                    self.fail "More than one package with the specified name [#{@model[:name]}], please use category/name to disambiguate"
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
