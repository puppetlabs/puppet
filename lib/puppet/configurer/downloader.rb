require 'puppet/configurer'
require 'puppet/resource/catalog'

class Puppet::Configurer::Downloader
  attr_reader :name, :path, :source, :ignore

  # Evaluate our download, returning the list of changed values.
  def evaluate
    Puppet.info _("Retrieving %{name}") % { name: name }

    files = []
    begin
      catalog.apply do |trans|
        trans.changed?.each do |resource|
          yield resource if block_given?
          files << resource[:path]
        end
      end
    rescue Puppet::Error => detail
      Puppet.log_exception(detail, _("Could not retrieve %{name}: %{detail}") % { name: name, detail: detail })
    end
    files
  end

  def initialize(name, path, source, ignore = nil, environment = nil, source_permissions = :ignore)
    @name, @path, @source, @ignore, @environment, @source_permissions = name, path, source, ignore, environment, source_permissions
  end

  def catalog
    catalog = Puppet::Resource::Catalog.new("PluginSync", @environment)
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

  def default_arguments
    defargs = {
      :path => path,
      :recurse => true,
      :links => :follow,
      :source => source,
      :source_permissions => @source_permissions,
      :tag => name,
      :purge => true,
      :force => true,
      :backup => false,
      :noop => false
    }
    if !Puppet.features.microsoft_windows?
      defargs.merge!(
        {
          :owner => Process.uid,
          :group => Process.gid
        }
      )
    end
    return defargs
  end
end
