# frozen_string_literal: true

require 'yaml'
# The `yaml_data` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
#
# @since 4.8.0
#
Puppet::Functions.create_function(:yaml_data) do
  # @since 4.8.0
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
        data = Puppet::Util::Yaml.safe_load(content, [Symbol], path)
        if data.is_a?(Hash)
          Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data)
        else
          msg = _("%{path}: file does not contain a valid yaml hash" % { path: path })
          raise Puppet::DataBinding::LookupError, msg if Puppet[:strict] == :error && data != false

          Puppet.warning(msg)
          {}
        end
      rescue Puppet::Util::Yaml::YamlLoadError => ex
        # YamlLoadErrors include the absolute path to the file, so no need to add that
        raise Puppet::DataBinding::LookupError, _("Unable to parse %{message}") % { message: ex.message }
      end
    end
  end

  def missing_path(options, context)
    "one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function"
  end
end
