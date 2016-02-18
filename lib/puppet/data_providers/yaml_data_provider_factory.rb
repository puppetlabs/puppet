# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'yaml'
require_relative 'hiera_interpolate'

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
    include HieraInterpolate

    def initialize_data(path, lookup_invocation)
      HieraConfig.symkeys_to_string(YAML.load_file(path))
    rescue YAML::SyntaxError => ex
      # Psych errors includes the absolute path to the file, so no need to add that
      # to the message
      raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
    end

    def post_process(value, lookup_invocation)
      interpolate(value, lookup_invocation, true)
    end
  end
end
