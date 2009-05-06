require 'puppet/configurer'
require 'puppet/resource/catalog'

class Puppet::Configurer::Downloader
    attr_reader :name, :path, :source, :ignore

    # Determine the timeout value to use.
    def self.timeout
        timeout = Puppet[:configtimeout]
        case timeout
        when String
            if timeout =~ /^\d+$/
                timeout = Integer(timeout)
            else
                raise ArgumentError, "Configuration timeout must be an integer"
            end
        when Integer # nothing
        else
            raise ArgumentError, "Configuration timeout must be an integer"
        end

        return timeout
    end

    # Evaluate our download, returning the list of changed values.
    def evaluate
        Puppet.info "Retrieving #{name}"

        files = []
        begin
            Timeout.timeout(self.class.timeout) do
                catalog.apply do |trans|
                    trans.changed?.find_all do |resource|
                        yield resource if block_given?
                        files << resource[:path]
                    end
                end
            end
        rescue Puppet::Error, Timeout::Error => detail
            puts detail.backtrace if Puppet[:debug]
            Puppet.err "Could not retrieve #{name}: %s" % detail
        end

        return files
    end

    def initialize(name, path, source, ignore = nil)
        @name, @path, @source, @ignore = name, path, source, ignore
    end

    def catalog
        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(file)
        catalog
    end

    def file
        args = default_arguments.merge(:path => path, :source => source)
        args[:ignore] = ignore.split if ignore
        Puppet::Type.type(:file).new(args)
    end

    private

    def default_arguments
        {
            :path => path,
            :recurse => true,
            :source => source,
            :tag => name,
            :owner => Process.uid,
            :group => Process.gid,
            :purge => true,
            :force => true,
            :backup => false,
            :noop => false
        }
    end
end
