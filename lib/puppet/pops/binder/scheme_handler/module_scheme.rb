require 'puppet/pops/binder/scheme_handler/symbolic_scheme'

# The module scheme allows loading bindings using the Puppet autoloader.
# Optional uris are handled by checking if the symbolic name can be resolved to a loadable file
# from modules.
# 
# URI
# ---
# The uri is on the format: `module:/[fqn][? | ?optional]` where `fqn` is a fully qualified bindings name
# starting with the module name or '*' to denote 'any module'. A URI query of `?` or `?optional` makes the
# request optional; if no loadable file is found, it is simply skipped.
#
#
# @todo
#   Does currently only support checking of optionality against files under a module. If the result should be loaded
#   from any other location it can not be marked as optional as it will be ignored.
#
module Puppet::Pops::Binder
class SchemeHandler::ModuleScheme < SchemeHandler::SymbolicScheme

  METADATA_DATA_PROVIDER = 'data_provider'.freeze

  def contributed_bindings(uri, scope, composer)
    split_name, fqn = fqn_from_path(uri)
    bindings = Puppet::Bindings.resolve(scope, split_name[0]) || load_bindings(uri, scope, composer, split_name, fqn)

    # Must clone as the rest mutates the model
    BindingsFactory.contributed_bindings(fqn, Marshal.load(Marshal.dump(bindings)))
  end

  # Expands URIs with wildcards and checks optionality.
  # @param uri [URI] the uri to possibly expand
  # @return [Array<URI>] the URIs to include
  # @api public
  #
  def expand_included(uri, composer)
    result = []
    split_name, fqn = fqn_from_path(uri)

    # supports wild card in the module name
    case split_name[0]
    when '*'
      # create new URIs, one per module name that has a corresponding data_provider entry in metadata.json
      # or an .rb file relative to its '<root>/lib/puppet/bindings/'
      #
      composer.name_to_module.each_pair do | module_name, mod |
        expanded_name_parts = [module_name] + split_name[1..-1]
        expanded_name = expanded_name_parts.join('::')

        if is_metadata?(split_name)
          if mod.metadata && mod.metadata[METADATA_DATA_PROVIDER]
            result << URI.parse('module:/' + expanded_name)
          end
        elsif BindingsLoader.loadable?(mod.path, expanded_name)
          result << URI.parse('module:/' + expanded_name)
        end
      end
    when nil
      raise ArgumentError, "Bad bindings uri, the #{uri} has neither module name or wildcard '*' in its first path position"
    else
      joined_name = split_name.join('::')
      module_name = split_name[0]
      # skip optional uri if it does not exist
      if is_optional?(uri)
        mod = composer.name_to_module[module_name]
        unless mod.nil?
          if is_metadata?(split_name)
            if mod.metadata && mod.metadata[METADATA_DATA_PROVIDER]
              result << URI.parse('module:/' + joined_name)
            end
          elsif BindingsLoader.loadable?(mod.path, joined_name)
            result << URI.parse('module:/' + joined_name)
          end
        end
      else
        # assume it exists (do not give error if not, since it may be excluded later)
        result << URI.parse('module:/' + joined_name)
      end
    end
    result
  end

  # Expands URIs with wildcards
  # @param uri [URI] the uri to possibly expand
  # @return [Array<URI>] the URIs to exclude
  # @api public
  #
  def expand_excluded(uri, composer)
    result = []
    split_name, fqn = fqn_from_path(uri)

    case split_name[ 0 ]
    when '*'
      # create new URIs, one per module name
      composer.name_to_module.each_pair do | name, mod |
        result << URI.parse('module:/' + ([name] + split_name).join('::'))
      end

    when nil
      raise ArgumentError, "Bad bindings uri, the #{uri} has neither module name or wildcard '*' in its first path position"
    else
      # create a clean copy (get rid of optional, fragments etc. and any trailing stuff
      result << URI.parse('module:/' + split_name.join('::'))
    end
    result
  end

  def load_bindings(uri, scope, composer, split_name, fqn)
    module_name = split_name[0]
    mod = composer.name_to_module[module_name]
    # given module name must exist
    raise ArgumentError, "Cannot load bindings '#{uri}' - module not found." if mod.nil?

    if is_metadata?(split_name)
      metadata = mod.metadata
      data_provider = metadata.nil? ? nil : metadata[METADATA_DATA_PROVIDER]
      unless data_provider.nil?
        # bind the data provider in a binding named after the module
        # loader.load('thallgren/sample_module_data', Puppet.lookup(:current_environment))
        Puppet::Bindings.newbindings(module_name) do
          bind {
            name(module_name)
            to(data_provider)
            in_multibind(Puppet::Plugins::DataProviders::PER_MODULE_DATA_PROVIDER_KEY)
          }
        end
        # pick up and return the just created and registered bindings
        bindings = Puppet::Bindings.resolve(scope, module_name)
      end
    else
      bindings = BindingsLoader.provide(scope, fqn)
    end
    raise ArgumentError, "Cannot load bindings '#{uri}' - no bindings found." unless bindings
    bindings
  end
  private :load_bindings

  def is_metadata?(split_name)
    split_name.size > 1 && split_name[1] == 'metadata'
  end
  private :is_metadata?
end
end
