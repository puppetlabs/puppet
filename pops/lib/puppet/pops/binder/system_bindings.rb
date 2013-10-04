class Puppet::Pops::Binder::SystemBindings
  # Constant with name used for bindings used during initialization of injector
  ENVIRONMENT_BOOT_BINDINGS_NAME = 'puppet::env::injector::boot'

  Factory = Puppet::Pops::Binder::BindingsFactory
  @extension_bindings = Factory.named_bindings("puppet::extensions")
  @default_bindings   = Factory.named_bindings("puppet::default")
  # Bindings in effect when real injector is created
  @injector_boot_bindings   = Factory.named_bindings("puppet::injector_boot")

  def self.extensions()
    @extension_bindings
  end

  def self.default_bindings()
    @default_bindings
  end

  def self.injector_boot_bindings()
    @injector_boot_bindings
  end

#  def self.env_boot_bindings()
#    Puppet::Bindings[Puppet::Pops::Binder::SystemBindings::ENVIRONMENT_BOOT_BINDINGS_NAME]
#  end

  def self.final_contribution
    effective_categories = Factory.categories([['common', 'true']])
    Factory.contributed_bindings("puppet-final", [deep_clone(@extension_bindings.model)], effective_categories)
  end

  def self.default_contribution
    effective_categories = Factory.categories([['common', 'true']])
    Factory.contributed_bindings("puppet-default", [deep_clone(@default_bindings.model)], effective_categories)
  end

  def self.injector_boot_contribution(env_boot_bindings)
    # Compose the injector_boot_bindings contributed from the puppet runtime book (i.e. defaults for
    # extensions that should be active in the boot injector - see Puppetx initialization.
    #
    bindings = [deep_clone(@injector_boot_bindings.model), deep_clone(@injector_default_bindings)]

    # Add the bindings that come from the bindings_composer as it may define custom extensions added in the bindings
    # configuration. (i.e. bindings required to be able to lookup using bindings schemes and backends when
    # configuring the real injector).
    #
    bindings << env_boot_bindings unless env_boot_bindings.nil?

    # Use an 'extension' category for extension bindings to allow them to override the default
    # bindings since they are placed in the same layer (this is done to avoid having a separate layer).
    # The purpose for allowing overrides is that someone may want to replace say 'yaml' with a different version,
    # (say one that uses a YAML implementation that actually works ok in ruby 1.8.7 ;-)), an encrypted parser, etc.
    effective_categories = Factory.categories([['extension', 'true'],['common', 'true']])

    # return the composition and the cateogires.
    Factory.contributed_bindings("puppet-injector-boot", bindings, effective_categories)
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
