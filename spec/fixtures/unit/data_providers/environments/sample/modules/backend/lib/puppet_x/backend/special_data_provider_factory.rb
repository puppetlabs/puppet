module PuppetX::Backend
  class SpecialDataProviderFactory < Puppet::Plugins::DataProviders::PathBasedDataProviderFactory
    def create(name, paths, parent_data_provider)
      SpecialDataProvider.new(name, paths)
    end

    def resolve_paths(datadir, declared_paths, paths, lookup_invocation)
      paths
    end
  end

  class SpecialDataProvider < Puppet::Plugins::DataProviders::PathBasedDataProvider
    def unchecked_lookup(key, lookup_invocation, merge)
      value = {
        'backend::test::param_a' => 'module data param_a is 1000',
        'backend::test::param_b' => 'module data param_b is 2000',
      }[key]
      throw :no_such_key if value.nil?
      value
    end
  end
end

