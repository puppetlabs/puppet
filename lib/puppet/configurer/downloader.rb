require 'puppet/configurer'
require 'puppet/resource/catalog'

class Puppet::Configurer::Downloader
  require 'puppet/util/config_timeout'
  class <<self
    include Puppet::Util::ConfigTimeout
  end
  
  attr_reader :name, :path, :source, :ignore

  # Evaluate our download, returning the list of changed values.
  def evaluate
    Puppet.info "Retrieving #{name}"

    files = []
    begin
      ::Timeout.timeout(self.class.timeout) do
        catalog.apply do |trans|
          trans.changed?.find_all do |resource|
            yield resource if block_given?
            files << resource[:path]
          end
        end
      end
    rescue Puppet::Error, Timeout::Error => detail
      puts detail.backtrace if Puppet[:debug]
      Puppet.err "Could not retrieve #{name}: #{detail}"
    end

    files
  end

  def initialize(name, path, source, ignore = nil)
    @name, @path, @source, @ignore = name, path, source, ignore
  end

  def catalog
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    catalog.add_resource(file)
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
      :owner => Puppet.features.microsoft_windows? ? Sys::Admin.get_login : Process.uid,
      :group => Puppet.features.microsoft_windows? ? 'S-1-0-0' : Process.gid,
      :purge => true,
      :force => true,
      :backup => false,
      :noop => false
    }
  end
end
