# This file is loaded by the autoloader, and it does not find the data function support unless required relative
#
require 'hocon'
require 'hocon/config_error'
require 'hocon/config_syntax'

module Puppet::DataProviders
  class HoconDataProviderFactory < Puppet::Plugins::DataProviders::FileBasedDataProviderFactory
    def create(name, paths, parent_data_provider)
      HoconDataProvider.new(name, paths, parent_data_provider)
    end

    def path_extension
      '.hocon'
    end
  end

  class HoconDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    def initialize_data(path, lookup_invocation)
      data = Hocon.load(File.absolute_path(path), {:syntax => Hocon::ConfigSyntax::HOCON})
    rescue Hocon::ConfigError::ConfigParseError => ex
      # Psych errors includes the absolute path to the file, so no need to add that
      # to the message
      raise Puppet::DataBinding::LookupError, "Unable to parse #{ex.message}"
    end
  end
end
