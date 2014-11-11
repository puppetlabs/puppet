# Abstract base class for schemes based on symbolic names of bindings.
# This class helps resolve symbolic names by computing a path from a fully qualified name (fqn).
# There are also helper methods do determine if the symbolic name contains a wild-card ('*') in the first
# portion of the fqn (with the convention that '*' means 'any module').
#
# @abstract
# @api public
#
class Puppet::Pops::Binder::SchemeHandler::SymbolicScheme < Puppet::Plugins::BindingSchemes::BindingsSchemeHandler

  # Shared implementation for module: and confdir: since the distinction is only in checks if a symbolic name
  # exists as a loadable file or not. Once this method is called it is assumed that the name is relative
  # and that it should exist relative to some loadable ruby location.
  #
  # TODO: this needs to be changed once ARM-8 Puppet DSL concrete syntax is also supported.
  # @api public
  #
  def contributed_bindings(uri, scope, composer)
    fqn = fqn_from_path(uri)[1]
    bindings = Puppet::Pops::Binder::BindingsLoader.provide(scope, fqn)
    raise ArgumentError, "Cannot load bindings '#{uri}' - no bindings found." unless bindings
    # Must clone as the rest mutates the model
    cloned_bindings = Marshal.load(Marshal.dump(bindings))
    Puppet::Pops::Binder::BindingsFactory.contributed_bindings(fqn, cloned_bindings)
  end

  # @api private
  def fqn_from_path(uri)
    split_path = uri.path.split('/')
    if split_path.size > 1 && split_path[-1].empty?
      split_path.delete_at(-1)
    end

    fqn = split_path[ 1 ]
    raise ArgumentError, "Module scheme binding reference has no name." unless fqn
    split_name = fqn.split('::')
    # drop leading '::'
    split_name.shift if split_name[0] && split_name[0].empty?
    [split_name, split_name.join('::')]
  end

  # True if super thinks it is optional or if it contains a wildcard.
  # @return [Boolean] true if the uri represents an optional set of bindings.
  # @api public
  def is_optional?(uri)
    super(uri) || has_wildcard?(uri)
  end

  # @api private
  def has_wildcard?(uri)
    (path = uri.path) && path.split('/')[1].start_with?('*::')
  end
end
