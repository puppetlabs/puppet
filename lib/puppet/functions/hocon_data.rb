# @since 4.9.0
#
Puppet::Functions.create_function(:hocon_data) do
  unless Puppet.features.hocon?
    raise Puppet::DataBinding::LookupError, 'Lookup using Hocon data_hash function is not supported without hocon library'
  end

  require 'hocon'
  require 'hocon/config_error'

  dispatch :hocon_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  def hocon_data(options, context)
    path = options['path']
    begin
      Hocon.parse(Puppet::FileSystem.read(path, :encoding => 'utf-8'))
    rescue Hocon::ConfigError => ex
      raise Puppet::DataBinding::LookupError, "Unable to parse (#{path}): #{ex.message}"
    end
  end
end
