module Puppet::Pops
module Binder
# The BindingsComposer handles composition of multiple bindings sources
# It is directed by a {Config::BinderConfig BinderConfig} that indicates how
# the final composition should be layered, and what should be included/excluded in each layer
#
# The bindings composer is intended to be used once per environment as the compiler starts its work.
#
# TODO: Possibly support envdir: scheme / relative to environment root (== same as confdir if there is only one environment).
#       This is probably easier to do after ENC changes described in ARM-8 have been implemented.
# TODO: If same config is loaded in a higher layer, skip it in the lower (since it is meaningless to load it again with lower
#       precedence. (Optimization, or possibly an error, should produce a warning).
#
require 'puppet/plugins/binding_schemes'

class BindingsComposer

  # The BindingsConfig instance holding the read and parsed, but not evaluated configuration
  # @api public
  #
  attr_reader :config

  # map of scheme name to handler
  # @api private
  attr_reader :scheme_handlers

  # @return [Hash{String => Puppet::Module}] map of module name to module instance
  # @api private
  attr_reader :name_to_module

  # @api private
  attr_reader :confdir

  # @api private
  attr_reader :diagnostics

  # Container of all warnings and errors produced while initializing and loading bindings
  #
  # @api public
  attr_reader :acceptor

  # @api public
  def initialize()
    @acceptor = Validation::Acceptor.new()
    @diagnostics = Config::DiagnosticProducer.new(acceptor)
    @config = Config::BinderConfig.new(@diagnostics)
    if acceptor.errors?
      IssueReporter.assert_and_report(acceptor, :message => 'Binding Composer: error while reading config.')
      raise Puppet::DevError.new("Internal Error: IssueReporter did not raise exception for errors in bindings config.")
    end
  end

  # Configures and creates the boot injector.
  # The read config may optionally contain mapping of bindings scheme handler name to handler class, and
  # mapping of biera2 backend symbolic name to backend class.
  # If present, these are turned into bindings in the category 'extension' (which is only used in the boot injector) which
  # has higher precedence than 'default'. This is done to allow users to override the default bindings for
  # schemes and backends.
  # @param scope [Puppet::Parser:Scope] the scope (used to find compiler and injector for the environment)
  # @api private
  #
  def configure_and_create_injector(scope)
    # create the injector (which will pick up the bindings registered above)
    @scheme_handlers = SchemeHandlerHelper.new(scope)

    # get extensions from the config
    # ------------------------------
    scheme_extensions = @config.scheme_extensions

    # Define a named bindings that are known by the SystemBindings
    boot_bindings = BindingsFactory.named_bindings(SystemBindings::ENVIRONMENT_BOOT_BINDINGS_NAME) do
      scheme_extensions.each_pair do |scheme, class_name|
        # turn each scheme => class_name into a binding (contribute to the buildings-schemes multibind).
        # do this in category 'extensions' to allow them to override the 'default'
        bind do
          name(scheme)
          instance_of(Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_TYPE)
          in_multibind(Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_KEY)
          to_instance(class_name)
          end
      end
    end

    @injector = scope.compiler.create_boot_injector(boot_bindings.model)
  end

  # @return [Bindings::LayeredBindings]
  def compose(scope)
    # The boot injector is used to lookup scheme-handlers
    configure_and_create_injector(scope)

    # get all existing modules and their root path
    @name_to_module = {}
    scope.environment.modules.each {|mod| name_to_module[mod.name] = mod }

    # setup the confdir
    @confdir = Puppet.settings[:confdir]

    factory = BindingsFactory
    contributions = []
    configured_layers = @config.layering_config.collect do |  layer_config |
      # get contributions
      contribs = configure_layer(layer_config, scope, diagnostics)
      # collect the contributions separately for later checking of category precedence
      contributions.concat(contribs)
      # create a named layer with all the bindings for this layer
      factory.named_layer(layer_config['name'], *contribs.collect {|c| c.bindings }.flatten)
    end

    # Add the two system layers; the final - highest ("can not be overridden" layer), and the lowest
    # Everything here can be overridden 'default' layer.
    #
    configured_layers.insert(0, SystemBindings.final_contribution)
    configured_layers.insert(-1, SystemBindings.default_contribution)

    # and finally... create the resulting structure
    factory.layered_bindings(*configured_layers)
  end

  private

  def configure_layer(layer_description, scope, diagnostics)
    name = layer_description['name']

    # compute effective set of uris to load (and get rid of any duplicates in the process
    included_uris = array_of_uris(layer_description['include'])
    excluded_uris = array_of_uris(layer_description['exclude'])
    effective_uris = Set.new(expand_included_uris(included_uris)).subtract(Set.new(expand_excluded_uris(excluded_uris)))

    # Each URI should result in a ContributedBindings
    effective_uris.collect { |uri| scheme_handlers[uri.scheme].contributed_bindings(uri, scope, self) }
  end

  def array_of_uris(descriptions)
    return [] unless descriptions
    descriptions = [descriptions] unless descriptions.is_a?(Array)
    descriptions.collect {|d| URI.parse(d) }
  end

  def expand_included_uris(uris)
    result = []
    uris.each do |uri|
      unless handler = scheme_handlers[uri.scheme]
        raise ArgumentError, "Unknown bindings provider scheme: '#{uri.scheme}'"
      end
      result.concat(handler.expand_included(uri, self))
    end
    result
  end

  def expand_excluded_uris(uris)
    result = []
    uris.each do |uri|
      unless handler = scheme_handlers[uri.scheme]
        raise ArgumentError, "Unknown bindings provider scheme: '#{uri.scheme}'"
      end
      result.concat(handler.expand_excluded(uri, self))
    end
    result
  end

  class SchemeHandlerHelper
    T = Types::TypeFactory
    HASH_OF_HANDLER = T.hash_of(T.type_of(Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_TYPE))
    def initialize(scope)
      @scope = scope
      @cache = nil
    end
    def [] (scheme)
      load_schemes unless @cache
      @cache[scheme]
    end

    def load_schemes
      @cache = @scope.compiler.boot_injector.lookup(@scope, HASH_OF_HANDLER, Puppet::Plugins::BindingSchemes::BINDINGS_SCHEMES_KEY) || {}
    end
  end

end
end
end
