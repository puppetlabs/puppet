require 'puppet/provider/package'

Puppet::Type.type(:package).provide :portage, :parent => Puppet::Provider::Package do
    desc "Provides packaging support for Gentoo's portage system."

    has_feature :versionable

    commands :emerge => "/usr/bin/emerge", :eix => "/usr/bin/eix", :update_eix => "/usr/bin/eix-update"

    confine :operatingsystem => :gentoo

    defaultfor :operatingsystem => :gentoo

    def self.instances
        result_format = /^(\S+)\s+(\S+)\s+\[(\S+)\]\s+\[(\S+)\]\s+(\S+)\s+(.*)$/
        result_fields = [:category, :name, :ensure, :version_available, :vendor, :description]

        version_format = "{last}<version>{}"
        search_format = "<category> <name> [<installedversions:LASTVERSION>] [<bestversion:LASTVERSION>] <homepage> <description>\n"

        begin
            if !FileUtils.uptodate?("/var/cache/eix", %w(/usr/bin/eix /usr/portage/metadata/timestamp))
                update_eix
            end

            search_output = nil
            Puppet::Util::Execution.withenv :LASTVERSION => version_format do
                search_output = eix "--nocolor", "--pure-packages", "--stable", "--installed", "--format", search_format
            end

            packages = []
            search_output.each do |search_result|
                match = result_format.match(search_result)

                if match
                    package = {}
                    result_fields.zip(match.captures) do |field, value|
                        package[field] = value unless !value or value.empty?
                    end
                    package[:provider] = :portage
                    packages << new(package)
                end
            end

            return packages
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new(detail)
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
        @resource[:category] ? "%s/%s" % [@resource[:category], @resource[:name]] : @resource[:name]
    end

    def uninstall
        emerge "--unmerge", package_name
    end

    def update
        self.install
    end

    def query
        result_format = /^(\S+)\s+(\S+)\s+\[(\S*)\]\s+\[(\S+)\]\s+(\S+)\s+(.*)$/
        result_fields = [:category, :name, :ensure, :version_available, :vendor, :description]

        version_format = "{last}<version>{}"
        search_format = "<category> <name> [<installedversions:LASTVERSION>] [<bestversion:LASTVERSION>] <homepage> <description>\n"

        search_field = package_name.count('/') > 0 ? "--category-name" : "--name"
        search_value = package_name

        begin
            if !FileUtils.uptodate?("/var/cache/eix", %w(/usr/bin/eix /usr/portage/metadata/timestamp))
                update_eix
            end

            search_output = nil
            Puppet::Util::Execution.withenv :LASTVERSION => version_format do
                search_output = eix "--nocolor", "--pure-packages", "--stable", "--format", search_format, "--exact", search_field, search_value
            end

            packages = []
            search_output.each do |search_result|
                match = result_format.match(search_result)

                if match
                    package = {}
                    result_fields.zip(match.captures) do |field, value|
                        package[field] = value unless !value or value.empty?
                    end
                    package[:ensure] = package[:ensure] ? package[:ensure] : :absent
                    packages << package
                end
            end

            case packages.size
                when 0
                    not_found_value = "%s/%s" % [@resource[:category] ? @resource[:category] : "<unspecified category>", @resource[:name]]
                    raise Puppet::Error.new("No package found with the specified name [#{not_found_value}]")
                when 1
                    return packages[0]
                else
                    raise Puppet::Error.new("More than one package with the specified name [#{search_value}], please use the category parameter to disambiguate")
            end
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error.new(detail)
        end
    end

    def latest
        return self.query[:version_available]
    end
end
