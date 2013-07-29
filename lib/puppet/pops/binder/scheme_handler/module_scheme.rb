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
class Puppet::Pops::Binder::SchemeHandler::ModuleScheme < Puppet::Pops::Binder::SchemeHandler::SymbolicScheme

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
      # create new URIs, one per module name that has a corresponding .rb file relative to its
      # '<root>/lib/puppet/bindings/'
      #
      composer.name_to_module.each_pair do | mod_name, mod |
        expanded_name_parts = [mod_name] + split_name[1..-1]
        expanded_name = expanded_name_parts.join('::')
        if Puppet::Pops::Binder::BindingsLoader.loadable?(mod.path, expanded_name)
          result << URI.parse('module:/' + expanded_name)
        end
      end
    when nil
      raise ArgumentError, "Bad bindings uri, the #{uri} has neither module name or wildcard '*' in its first path position"
    else
      joined_name = split_name.join('::')
      # skip optional uri if it does not exist
      if is_optional?(uri)
        mod = composer.name_to_module[split_name[0]]
        if mod && Puppet::Binder::BindingsLoader.loadable?(mod.path, joined_name)
          result << URI.parse('module:/' + joined_name)
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
end
