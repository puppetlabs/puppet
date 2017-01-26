# @since 4.9.0
#
Puppet::Functions.create_function(:hocon_data) do
  unless Puppet.features.hocon?
    raise Puppet::DataBinding::LookupError, _('Lookup using Hocon data_hash function is not supported without hocon library')
  end

  require 'hocon'
  require 'hocon/config_error'

  dispatch :hocon_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  argument_mismatch :missing_path do
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def hocon_data(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      begin
        Hocon.parse(content)
      rescue Hocon::ConfigError => ex
        raise Puppet::DataBinding::LookupError, "Unable to parse (#{path}): #{ex.message}"
      end
    end
  end

  def missing_path(options, context)
    "one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function"
  end
end
