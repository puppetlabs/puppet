# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'yaml'

module Puppet::DataProviders
  class YamlDataProviderFactory < Puppet::Plugins::DataProviders::FileBasedDataProviderFactory
    def create(name, paths, parent_data_provider)
      YamlDataProvider.new(name, paths, parent_data_provider)
    end

    def path_extension
      '.yaml'
    end
  end

  class YamlDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    def initialize_data(path, lookup_invocation)
      data = YAML.load_file(path)
      HieraConfig.symkeys_to_string(data.nil? ? {} : data)
    rescue YAML::SyntaxError => ex
      # Psych errors includes the absolute path to the file, so no need to add that
      # to the message
      raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
    end
  end
end
