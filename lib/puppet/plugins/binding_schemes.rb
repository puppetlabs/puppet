require 'puppet/plugins'
module Puppet::Plugins::BindingSchemes

  # The lookup **key** for the multibind containing a map from scheme name to scheme handler class for bindings schemes.
  # @api public
  BINDINGS_SCHEMES_KEY  = 'puppet::binding::schemes'

  # The lookup **type** for the multibind containing a map from scheme name to scheme handler class for bindings schemes.
  # @api public
  BINDINGS_SCHEMES_TYPE = 'Puppet::Plugins::BindingSchemes::BindingsSchemeHandler'

  # BindingsSchemeHandler is a Puppet Extension Point for the purpose of extending Puppet with a
  # handler of a URI scheme used in the Puppet Bindings / Injector system.
  # The intended use is to create a class derived from this class and then register it with the
  # Puppet Binder.
  #
  # Creating the Extension Class
  # ----------------------------
  # As an example, a class for getting LDAP data and transforming into bindings based on an LDAP URI scheme (such as RFC 2255, 4516)
  # may be authored in say a puppet module called 'exampleorg/ldap'. The name of the class should start with `Puppetx::<user>::<module>`,
  # e.g. 'Puppetx::Exampleorg::Ldap::LdapBindingsSchemeHandler" and
  # be located in `lib/puppetx/exampleorg/Ldap/LdapBindingsSchemeHandler.rb`. (These rules are not enforced, but it makes the class
  # both auto-loadable, and guaranteed to not have a name that clashes with some other LdapBindingsSchemeHandler from some other
  # author/organization.
  #
  # The Puppet Binder will auto-load the file when it
  # has a binding to the class `Puppetx::Exampleorg::Ldap::LdapBindingsSchemeHandler'
  # The Ruby Module `Puppetx` is created by Puppet, the remaining modules should be created by the loaded logic - e.g.:
  #
  # @example Defining an LdapBindingsSchemeHandler
  #   module Puppetx::Exampleorg
  #     module Ldap
  #       class LdapBindingsSchemeHandler < Puppetx::Puppetlabs::BindingsSchemeHandler
  #         # implement the methods
  #       end
  #     end
  #   end
  #
  #
  # The expand_included method
  # --------------------------
  # This method is given a URI (as entered by a user in a bindings configuration) and the handler's first task is to
  # perform checking, transformation, and possible expansion into multiple URIs for loading. The result is always an array
  # of URIs. This method allows users to enter wild-cards, or to represent something symbolic that is transformed into one or
  # more "real URIs" to load. (It is allowed to change scheme!).
  # If the "optional" feature is supported, the handler should not include the URI in the result unless it will be able to produce
  # bindings for the given URI (as an option it may produce an empty set of bindings).
  #
  # The expand_excluded method
  # ---------------------------
  # This method is given an URI (as entered by the user in a bindings configuration), and it is the handler's second task
  # to perform checking, transformation, and possible expansion into multiple URIs that should not be loaded. The result is always
  # an array of URIs. The user may be allowed to enter wild-cards etc. The URIs produced by this method should have the same syntax
  # as those produced by {#expand_included} since they are excluded by comparison.
  #
  # The contributed_bindings method
  # -------------------------------
  # As the last step, the handler is being called once per URI that was included, and not later excluded to produce the
  # contributed bindings. It is given three arguments, uri (the uri to load), scope (to provide access to the rest of the
  # environment), and an acceptor (of issues), on which issues can be recorded.
  #
  # Reporting Errors/Issues
  # -----------------------
  # Issues are reported by calling the given composer's acceptor, which takes a severity (e.g. `:error`,
  # `:warning`, or `:ignore`), an {Puppet::Pops::Issues::Issue Issue} instance, and a {Puppet::Pops::Adapters::SourcePosAdapter
  # SourcePosAdapter} (which describes details about linenumber, position, and length of the problem area). If the scheme is
  # not based on file, line, pos - nil can be passed. The URI itself can be passed as file.
  #
  # @example Reporting an issue
  #    # create an issue with a symbolic name (that can serve as a reference to more details about the problem),
  #    # make the name unique
  #    issue = Puppet::Pops::Issues::issue(:EXAMPLEORG_LDAP_ILLEGAL_URI) { "The URI is not a valid Ldap URI" }
  #    source_pos = nil
  #
  #    # report it
  #    composer.acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, uri.to_s, source_pos, {}))
  #
  # Instead of reporting issues, an exception can be raised.
  #
  # @abstract
  # @api public
  #
  class BindingsSchemeHandler
    # Produces the bindings contributed to the binding system based on the given URI.
    # @param uri [URI] the URI to load bindings from
    # @param scope [Puppet::Pops::Parser::Scope] access to scope and the rest of the environment
    # @param composer [Puppet::Pops::Binder::BindingsComposer] a composer giving access to modules by name, and a diagnostics acceptor
    # @return [Puppet::Pops::Binder::Bindings::ContributedBindings] the bindings to contribute, most conveniently
    #   created by calling {Puppet::Pops::Binder::BindingsFactory.contributed_bindings}.
    # @api public
    #
    def contributed_bindings(uri, scope, composer)
      raise NotImplementedError, "The BindingsProviderScheme for uri: '#{uri}' must implement 'contributed_bindings'"
    end

    # Expands the given URI for the purpose of including the bindings it refers to. The input may contain
    # wild-cards (if supported by this handler), and it is this methods responsibility to transform such into
    # real loadable URIs.
    #
    # A scheme handler that does not support optionality, or wildcards should simply return the given URI
    # in an Array.
    #
    # @param uri [URI] the uri for which bindings are to be produced.
    # @param composer [Puppet::Pops::Binder::BindingsComposer] a composer giving access to modules by name, and a diagnostics acceptor
    # @return [Array<URI>] the transformed, and possibly expanded set of URIs to include.
    # @api public
    #
    def expand_included(uri, composer)
      [uri]
    end

    # Expands the given URI for the purpose of excluding the bindings it refers to. The input may contain
    # wild-cards (if supported by this handler), and it is this methods responsibility to transform such into
    # real loadable URIs (that match those produced by {#expand_included} that should be excluded from the result.
    #
    # A scheme handler that does not support optionality, or wildcards should simply return the given URI
    # in an Array.
    #
    # @param uri [URI] the uri for which bindings are to be produced.
    # @param composer [Puppet::Pops::Binder::BindingsComposer] a composer giving access to modules by name, and a diagnostics acceptor
    # @return [Array<URI>] the transformed, and possibly expanded set of URIs to include-
    # @api public
    #
    def expand_excluded(uri, composer)
      [uri]
    end

    # Returns whether the uri is optional or not. A scheme handler does not have to use this method
    # to determine optionality, but if it supports such a feature, and there is no technical problem in supporting
    # it this way, it should be done the same (or at least similar) way across all scheme handlers.
    #
    # This method interprets a URI ending with `?` or has query that is '?optional' as optional.
    #
    # @return [Boolean] whether the uri is an optional reference or not.
    def is_optional?(uri)
      (query = uri.query) && query == '' || query == 'optional'
    end
  end

end
