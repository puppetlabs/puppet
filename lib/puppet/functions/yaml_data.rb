# @since 4.8.0
#
require 'yaml'

Puppet::Functions.create_function(:yaml_data) do
  dispatch :yaml_data do
    param 'Struct[{path=>String[1]}]', :options
    param 'Puppet::LookupContext', :context
  end

  def yaml_data(options, context)
    begin
      data = YAML.load_file(options['path'])
      Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data.nil? ? {} : data)
    rescue YAML::SyntaxError => ex
      # Psych errors includes the absolute path to the file, so no need to add that
      # to the message
      raise Puppet::DataBinding::LookupError, _("Unable to parse #{ex.message}")
    end
  end
end
