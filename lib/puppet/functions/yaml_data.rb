# The `yaml_data` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://docs.puppet.com/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
#
# @since 4.8.0
#
require 'yaml'

Puppet::Functions.create_function(:yaml_data) do
  dispatch :yaml_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  argument_mismatch :missing_path do
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def yaml_data(options, context)
    path = options['path']
    context.cached_file_data(path) do |content|
      begin
        data = YAML.load(content, path)
        if data.is_a?(Hash)
          Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data)
        else
          msg = _("%{path}: file does not contain a valid yaml hash" % { path: path })
          raise Puppet::DataBinding::LookupError, msg if Puppet[:strict] == :error && data != false
          Puppet.warning(msg)
          {}
        end
      rescue YAML::SyntaxError => ex
        # Psych errors includes the absolute path to the file, so no need to add that
        # to the message
        raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
      end
    end
  end

  def missing_path(options, context)
    "one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function"
  end
end
