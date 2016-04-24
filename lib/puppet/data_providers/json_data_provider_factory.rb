# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'json'

module Puppet::DataProviders
  class JsonDataProviderFactory < Puppet::Plugins::DataProviders::FileBasedDataProviderFactory
    def create(name, paths, parent_data_provider)
      JsonDataProvider.new(name, paths, parent_data_provider)
    end

    def path_extension
      '.json'
    end
  end

  class JsonDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    def initialize_data(path, lookup_invocation)
      JSON.parse(Puppet::FileSystem.read(path, :encoding => 'utf-8'))
    rescue JSON::ParserError => ex
      # Filename not included in message, so we add it here.
      raise Puppet::DataBinding::LookupError, "Unable to parse (#{path}): #{ex.message}"
    end
  end
end
