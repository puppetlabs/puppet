# frozen_string_literal: true

require_relative '../../puppet/configurer'
require_relative '../../puppet/resource/catalog'

class Puppet::Configurer::Downloader
  attr_reader :name, :path, :source, :ignore

  # Evaluate our download, returning the list of changed values.
  def evaluate
    Puppet.info _("Retrieving %{name}") % { name: name }

    files = []
    begin
      catalog.apply do |trans|
        unless Puppet[:ignore_plugin_errors]
          # Propagate the first failure associated with the transaction. The any_failed?
          # method returns the first resource status that failed or nil, not a boolean.
          first_failure = trans.any_failed?
          if first_failure
            event = (first_failure.events || []).first
            detail = event ? event.message : 'unknown'
            raise Puppet::Error.new(_("Failed to retrieve %{name}: %{detail}") % { name: name, detail: detail })
          end
        end

        trans.changed?.each do |resource|
          yield resource if block_given?
          files << resource[:path]
        end
      end
    rescue Puppet::Error => detail
      if Puppet[:ignore_plugin_errors]
        Puppet.log_exception(detail, _("Could not retrieve %{name}: %{detail}") % { name: name, detail: detail })
      else
        raise detail
      end
    end
    files
  end

  def initialize(name, path, source, ignore = nil, environment = nil, source_permissions = :ignore)
    @name = name
    @path = path
    @source = source
    @ignore = ignore
    @environment = environment
    @source_permissions = source_permissions
  end

  def file
    unless @file
      args = default_arguments.merge(:path => path, :source => source)
      args[:ignore] = ignore.split if ignore
      @file = Puppet::Type.type(:file).new(args)
    end
    @file
  end

  def catalog
    unless @catalog
      @catalog = Puppet::Resource::Catalog.new("PluginSync", @environment)
      @catalog.host_config = false
      @catalog.add_resource(file)
    end
    @catalog
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
      :noop => false,
      :max_files => -1
    }
    unless Puppet::Util::Platform.windows?
      defargs[:owner] = Process.uid
      defargs[:group] = Process.gid
    end
    return defargs
  end
end
