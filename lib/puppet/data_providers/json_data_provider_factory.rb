# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'json'

module Puppet::DataProviders
  # TODO: API 5.0, remove this class
  # @api private
  # @deprecated
  class JsonDataProviderFactory < Puppet::Plugins::DataProviders::FileBasedDataProviderFactory
    def create(name, paths, parent_data_provider)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'Puppet::DataProviders::JsonDataProviderFactory',
          'Puppet::DataProviders::JsonDataProviderFactory is deprecated and will be removed in the next major version of Puppet')
      end
      JsonDataProvider.new(name, paths, parent_data_provider)
    end

    def path_extension
      '.json'
    end
  end

  # TODO: API 5.0, remove this class
  # @api private
  # @deprecated
  class JsonDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    def initialize_data(path, lookup_invocation)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'Puppet::DataProviders::JsonDataProvider',
          'Puppet::DataProviders::JsonDataProvider is deprecated and will be removed in the next major version of Puppet')
      end
      JSON.parse(Puppet::FileSystem.read(path, :encoding => 'utf-8'))
    rescue JSON::ParserError => ex
      # Filename not included in message, so we add it here.
      raise Puppet::DataBinding::LookupError, "Unable to parse (#{path}): #{ex.message}"
    end
  end
end
