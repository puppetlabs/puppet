# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'yaml'
require_relative 'hiera_interpolate'

module Puppet::DataProviders
  class YamlDataProviderFactory < Puppet::Plugins::DataProviders::FileBasedDataProviderFactory
    def create(name, paths)
      YamlDataProvider.new(name, paths)
    end

    def path_extension
      '.yaml'
    end
  end

  class YamlDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    include HieraInterpolate

    def initialize_data(path, lookup_invocation)
      HieraConfig.symkeys_to_string(YAML.load_file(path))
    end

    def post_process(value, lookup_invocation)
      interpolate(value, lookup_invocation, true)
    end
  end
end
