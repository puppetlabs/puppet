# The `module-hiera:` scheme uses the path to denote a directory relative to a module root
# The path starts with the name of the module, or '*' to denote *any module*.
#
# @example All root hiera.yaml from all modules.
#   module-hiera:/*
#
# @example The hiera.yaml from the module `foo`'s relative path `<foo root>/bar`.
#   module-hiera:/foo/bar
#
class Puppet::Pops::Binder::SchemeHandler::ModuleHieraScheme < Puppetx::Puppet::BindingsSchemeHandler
  # (Puppetx::Puppet::BindingsSchemeHandler.contributed_bindings)
  # @api public
  def contributed_bindings(uri, scope, composer)
    split_path = uri.path.split('/')
    name = split_path[1]
    mod = composer.name_to_module[name]
    provider = Puppet::Pops::Binder::Hiera2::BindingsProvider.new(uri.to_s, File.join(mod.path, split_path[ 2..-1 ]), composer.acceptor)
    provider.load_bindings(scope)
  end

  # Expands URIs with wildcards and checks optionality.
  # @param uri [URI] the uri to possibly expand
  # @return [Array<URI>] the URIs to include
  # @api public
  #
  def expand_included(uri, composer)
    result = []
    split_path = uri.path.split('/')
    if split_path.size > 1 && split_path[-1].empty?
      split_path.delete_at(-1)
    end

    # 0 = "", since a URI with a path must start with '/'
    # 1 = '*' or the module name
    case split_path[ 1 ]
    when '*'
      # create new URIs, one per module name that has a hiera.yaml file relative to its root
      composer.name_to_module.each_pair do | name, mod |
        if Puppet::FileSystem::File.exist?(File.join(mod.path, split_path[ 2..-1 ], 'hiera.yaml' ))
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
          if Puppet::FileSystem::File.exist?(File.join(mod.path, split_path[ 2..-1 ], 'hiera.yaml' ))
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

  # Expands URIs with wildcards and checks optionality.
  # @param uri [URI] the uri to possibly expand
  # @return [Array<URI>] the URIs to exclude
  # @api public
  #
  def expand_excluded(uri, composer)
    result = []
    split_path = uri.path.split('/')
    if split_path.size > 1 && split_path[-1].empty?
      split_path.delete_at(-1)
    end

    # 0 = "", since a URI with a path must start with '/'
    # 1 = '*' or the module name
    case split_path[ 1 ]
    when '*'
      # create new URIs, one per module name that has a hiera.yaml file relative to its root
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
