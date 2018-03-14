# The `json_data` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://docs.puppet.com/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
#
# @since 4.8.0
#
Puppet::Functions.create_function(:json_data) do
  dispatch :json_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  argument_mismatch :missing_path do
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def json_data(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      begin
        Puppet::Util::Json.load(content)
      rescue Puppet::Util::Json::ParseError => ex
        # Filename not included in message, so we add it here.
        raise Puppet::DataBinding::LookupError, "Unable to parse (%{path}): %{message}" % { path: path, message: ex.message }
      end
    end
  end

  def missing_path(options, context)
    "one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function"
  end
end
