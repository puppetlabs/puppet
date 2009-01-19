require 'puppet/agent'

# A simple class that abstracts downloading files
# fromthe server.
class Puppet::Agent::Downloader
    attr_reader :name, :path, :source, :ignore

    # Evaluate our download, returning the list of changed values.
    def evaluate
        Puppet.info "Retrieving #{name}"

        files = []
        begin
            Timeout.timeout(Puppet::Agent.timeout) do
                catalog.apply do |trans|
                    trans.changed?.find_all do |resource|
                        yield resource[:path] if block_given?
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
        catalog = Puppet::Node::Catalog.new
        catalog.add_resource(file)
        catalog
    end

    def file
        args = default_arguments.merge(:path => path, :source => source)
        args[:ignore] = ignore if ignore
        Puppet::Type.type(:file).create(args)
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
