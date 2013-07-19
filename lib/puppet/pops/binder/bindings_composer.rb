# The BindingsComposer handles composition of multiple bindings sources
# It is directed by a {Puppet::Pops::Binder::Config::BinderConfig BinderConfig} that indicates how
# the final composition should be layered, and what should be included/excluded in each layer
#
# TODO: Lookup and provide the confdir (needed by confdir-hiera scheme);
# TODO: Also support envdir scheme / relative to environment root (== same as confdir if there is only one environment)
# TODO: If same config is loaded in a higher layer, skip it in the lower (since it is meaningless to load it again with lower
#       precedence
# TODO: Hiera2 bindings provider changed API
# TODO: Hiera2 bindings, ::fact vs fact
# TODO: Combine layers
# TODO: Driving the overall precedence of categories; configured or composed?
#       If top layer is hiera2 - it defines all categories, but where are they otherwise stored?
#       In bindings_config?
#
#
class Puppet::Pops::Binder::BindingsComposer
  # The BindingsConfig instance holding the read and parsed configuration
  attr_reader :config

  # map of scheme name to handler
  attr_reader :scheme_handlers

  # @return Hash<String, Puppet::Module> map of module name to module instance
  attr_reader :name_to_module

  attr_reader :confdir

  # @api private
  attr_reader :diagnostics

  # Container of all warnings and errors produced while initializing and loading bindings
  #
  # @api public
  attr_reader :acceptor
  # TODO: consider giving it an acceptor (and report errors later)
  #
  def initialize()
    @acceptor = Puppet::Pops::Validation::Acceptor.new()
    @diagnostics = Puppet::Pops::Binder::Config::DiagnosticProducer.new(acceptor)
    @config = Puppet::Pops::Binder::Config::BinderConfig.new(@diagnostics)
    if acceptor.errors?
      # The EParserAdapter has general reporting logic - should be generalized and reused here
      # for reporting the problems and bailing out.
      #
      raise Puppet::ParseError.new("Binding Composer: error while reading config. TODO: proper reporting")
    end
  end

  # @return [Puppet::Pops::Binder::Bindings::LayeredBindings]
  def compose(scope)
    # Configure the scheme handlers.
    # Do this now since there is a scope (which makes it possible to get to other information
    # TODO: Make it possible to register scheme handlers
    #
    @scheme_handlers = { 'module-hiera' => ModuleHieraScheme.new(self), 'confdir-hiera' => ConfdirHieraScheme.new(self) }

    # get all existing modules and their root path
    @name_to_module = {}
    scope.environment.modules.each {|mod| name_to_module[mod.name] = mod }

    # setup the confdir
    @confdir = Puppet.settings[:confdir]

    factory = Puppet::Pops::Binder::BindingsFactory
    contributions = []
    configured_layers = @config.layering_config.collect do |  layer_config |
      # get contributions with effective categories
      contribs = configure_layer(layer_config, scope, diagnostics)
      # collect the contributions separately for later checking of category precedence
      contributions.concat(contribs)
      # create a named layer with all the bindings for this layer
      factory.named_layer(layer_config['name'], *contribs.collect {|c| c.bindings }.flatten)
    end

    # must check all contributions are based on compatible category precedence
    # (Note that contributions no longer contains the bindings as a side effect of setting them in the collected
    # layer. The effective categories and the name remains in the contributed model; this is enough for checking
    # and error reporting).
    check_contribution_precedence(contributions)

    # Add the two system layers; the final - highest ("can not be overridden" layer), and the lowest
    # Everything here can be overridden 'default' layer.
    #
    configured_layers.insert(0, Puppet::Pops::Binder::SystemBindings.final_contribution)
    configured_layers.insert(-1, Puppet::Pops::Binder::SystemBindings.default_contribution)

    # and finally... create the resulting structure
    factory.layered_bindings(*configured_layers)
  end

  # Checks that contribution's effective categorization is in the same relative order as in the overall
  # categorization precedence.
  #
  def check_contribution_precedence(contributions)
    cat_prec = { }
    @config.categorization.each_with_index {|c, i| cat_prec[ c[0] ] = i }
    contributions.each() do |contrib|
      # Contributions that do not specify their opinion about categorization silently accepts the precedence
      # set in the root configuration - and may thus produce an unexpected result
      #
      next unless ec = contrib.effective_categories
      next unless categories = ec.categories
      prev_prec = -1
      categories.each do |c|
        prec = cat_prec[c.categorization]
        unless prec
          acceptor.accept(Issues::MISSING_CATEGORY_PRECEDENCE, c, :categorization => c.categorization)
          next
        end
        unless prec > prev_prec
          acceptor.accept(Issues::PRECEDENCE_MISMATCH_IN_CONTRIBUTION, c, :categorization => c.categorization)
        end
        prev_prec = prec
      end
    end
  end

  def configure_layer(layer_description, scope, diagnostics)
    name = layer_description['name']

    # compute effective set of uris to load (and get rid of any duplicates in the process
    included_uris = array_of_uris(layer_description['include'])
    excluded_uris = array_of_uris(layer_description['exclude'])
    effective_uris = Set.new(expand_included_uris(included_uris)).subtract(Set.new(expand_excluded_uris(excluded_uris)))

    # Each URI should result in a ContributedBindings
    effective_uris.collect { |uri| scheme_handlers[uri.scheme].contributed_bindings(uri, scope, diagnostics) }
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
      result.concat(handler.expand_included(uri))
    end
    result
  end

  def expand_excluded_uris(uris)
    result = []
    uris.each do |uri|
      unless handler = scheme_handlers[uri.scheme]
        raise ArgumentError, "Unknown bindings provider scheme: '#{uri.scheme}'"
      end
      result.concat(handler.expand_excluded(uri))
    end
    result
  end
end

# @abstract
class BindingsProviderScheme
  attr_reader :composer
  def initialize(composer)
    @composer = composer
  end
end

# @abstract
class HieraScheme < BindingsProviderScheme
end

class ConfdirHieraScheme < HieraScheme
  def contributed_bindings(uri, scope, diagnostics)
    split_path = uri.path.split('/')
    name = split_path[1]
    confdir = composer.confdir
    provider = Puppet::Pops::Binder::Hiera2::BindingsProvider.new(uri.to_s, File.join(confdir, uri.path), composer.acceptor)
    provider.load_bindings(scope)
  end

  # Similar to ModuleHieraScheme, but relative to the config root. Does not support wildcard expansion
  def expand_included(uri)
    [uri]
  end

  def expand_excluded(uri)
    [uri]
  end
end

# The module hiera scheme uses the path to denote a directory relative to a module root
# The path starts with the name of the module, or '*' to denote *any module*.
# @example All root hiera_config.yaml from all modules
#   module-hiera:/*
# @example The hiera_config.yaml from the module `foo`'s relative path `<foo root>/bar`
#   module-hiera:/foo/bar
#
class ModuleHieraScheme < HieraScheme
  # @return [Puppet::Pops::Binder::Bindings::ContributedBindings] the bindings contributed from the config
  def contributed_bindings(uri, scope, diagnostics)
    split_path = uri.path.split('/')
    name = split_path[1]
    mod = composer.name_to_module[name]
    provider = Puppet::Pops::Binder::Hiera2::BindingsProvider.new(uri.to_s, File.join(mod.path, split_path[ 2..-1 ]), composer.acceptor)
    provider.load_bindings(scope)
  end

  def expand_included(uri)
    result = []
    split_path = uri.path.split('/')
    if split_path.size > 1 && split_path[-1].empty?
      split_path.delete_at(-1)
    end

    # 0 = "", since a URI with a path must start with '/'
    # 1 = '*' or the module name
    case split_path[ 1 ]
    when '*'
      # create new URIs, one per module name that has a hiera_config.yaml file relative to its root
      composer.name_to_module.each_pair do | name, mod |
        if File.exist?(File.join(mod.path, split_path[ 2..-1 ], 'hiera_config.yaml' ))
          path_parts =["", name] + split_path[2..-1]
          result << URI.parse('module-hiera:'+File.join(path_parts))
        end
      end
    when nil
      raise ArgumentError, "Bad bindings uri, the #{uri} has neither module name or wildcard '*' in its first path position"
    else
      # If uri has query that is empty, or the text 'optional' skip this uri if it does not exist
      if query = uri.query()
        if query == '' || query == 'optional'
          if File.exist?(File.join(mod.path, split_path[ 2..-1 ], 'hiera_config.yaml' ))
            result << URI.parse('module-hiera:' + uri.path)
          end
        end
      else
        # assume it exists (do not give error since it may be excluded later)
        result << URI.parse('module-hiera:' + File.join(split_path))
      end
    end
    result
  end

  def expand_excluded(uri)
    result = []
    split_path = uri.path.split('/')
    if split_path.size > 1 && split_path[-1].empty?
      split_path.delete_at(-1)
    end

    # 0 = "", since a URI with a path must start with '/'
    # 1 = '*' or the module name
    case split_path[ 1 ]
    when '*'
      # create new URIs, one per module name that has a hiera_config.yaml file relative to its root
      composer.name_to_module.each_pair do | name, mod |
        path_parts =["", mod.name] + split_path[2..-1]
        result << URI.parse('module-hiera:'+File.join(path_parts))
      end

    when nil
      raise ArgumentError, "Bad bindings uri, the #{uri} has neither module name or wildcard '*' in its first path position"
    else
      # create a clean copy (get rid of optional, fragments etc. and a trailing "/")
      result << URI.parse('module-hiera:' + File.join(split_path))
    end
    result
  end
end

