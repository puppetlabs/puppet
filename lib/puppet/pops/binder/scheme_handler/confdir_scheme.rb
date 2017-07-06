require 'puppet/pops/binder/scheme_handler/symbolic_scheme'

# Similar to {Puppet::Pops::Binder::SchemeHandler::ModuleScheme ModuleScheme}, but relative to the config root.
# Does not support wildcard expansion.
#
# URI
# ---
# The URI scheme is `confdir:/[<FQN>]['?' | [?optional]` where FQN is the fully qualified name of the bindings to load.
# The reference is made optional by using a URI query of `?` or `?optional`.
#
# @todo
#   If the file to load is outside of the file system rooted at $confdir (in a gem, or just on the Ruby path), it can not
#   be marked as optional as it will always be ignored.
#
class Puppet::Pops::Binder::SchemeHandler::ConfdirScheme < Puppet::Pops::Binder::SchemeHandler::SymbolicScheme

  def expand_included(uri, composer)
    fqn = fqn_from_path(uri)[1]
    if is_optional?(uri)
      if Puppet::Pops::Binder::BindingsLoader.loadable?(composer.confdir, fqn)
        [URI.parse('confdir:/' + fqn)]
      else
        []
      end
    else
      # assume it exists (do not give error if not, since it may be excluded later)
      [URI.parse('confdir:/' + fqn)]
    end
  end

  def expand_excluded(uri, composer)
    [URI.parse("confdir:/#{fqn_from_path(uri)[1]}")]
  end
end
