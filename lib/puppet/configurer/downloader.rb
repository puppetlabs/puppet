require 'puppet/configurer'
require 'puppet/resource/catalog'

class Puppet::Configurer::Downloader
  attr_reader :name, :path, :source, :ignore

  # Evaluate our download, returning the list of changed values.
  def evaluate
    Puppet.info "Retrieving #{name}"

    files = []
    begin
      ::Timeout.timeout(Puppet[:configtimeout]) do
        catalog.apply do |trans|
          trans.changed?.find_all do |resource|
            yield resource if block_given?
            files << resource[:path]
          end
        end
      end
    rescue Puppet::Error, Timeout::Error => detail
      Puppet.log_exception(detail, "Could not retrieve #{name}: #{detail}")
    end

    files
  end

  def initialize(name, path, source, ignore = nil, environment = nil)
    @name, @path, @source, @ignore, @environment = name, path, source, ignore, environment
  end

  def catalog
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    catalog.add_resource(file)
    catalog.environment = @environment
    catalog
  end

  def file
    args = default_arguments.merge(:path => path, :source => source)
    args[:ignore] = ignore.split if ignore
    Puppet::Type.type(:file).new(args)
  end

  private

  require 'sys/admin' if Puppet.features.microsoft_windows?

  def default_arguments
    {
      :path => path,
      :recurse => true,
      :source => source,
      :tag => name,
      :purge => true,
      :force => true,
      :backup => false,
      :noop => false
    }.merge(
      Puppet.features.microsoft_windows? ? {} :
      {
        :owner => Process.uid,
        :group => Process.gid
      }
    )
  end
end
