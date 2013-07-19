class Puppet::Pops::Binder::SystemBindings
  Factory = Puppet::Pops::Binder::BindingsFactory
  @extension_bindings = Factory.named_bindings("puppet::extensions")
  @default_bindings   = Factory.named_bindings("puppet::default")

  def self.extensions()
    @extension_bindings
  end

  def self.default_bindings()
    @default_bindings
  end

  def self.final_contribution
    effective_categories = Factory.categories([['common', 'true']])
    Factory.contributed_bindings("puppet-final", [deep_clone(@extension_bindings.model)], effective_categories)
  end

  def self.default_contribution
    effective_categories = Factory.categories([['common', 'true']])
    Factory.contributed_bindings("puppet-default", [deep_clone(@default_bindings.model)], effective_categories)
  end

  def self.factory()
    Puppet::Pops::Binder::BindingsFactory
  end

  def self.type_factory()
    Puppet::Pops::Types::TypeFactory
  end

  private

  def self.deep_clone(o)
    Marshal.load(Marshal.dump(o))
  end
end
