module Puppet::Plugins
module SyntaxCheckers

  # The lookup **key** for the multibind containing syntax checkers used to syntax check embedded string in non
  # puppet DSL syntax.
  # @api public
  SYNTAX_CHECKERS_KEY = :'puppet::syntaxcheckers'

  # SyntaxChecker is a Puppet Extension Point for the purpose of extending Puppet with syntax checkers.
  # The intended use is to create a class derived from this class and then register it with the Puppet context
  #
  # Creating the Extension Class
  # ----------------------------
  # As an example, a class for checking custom xml (aware of some custom schemes) may be authored in
  # say a puppet module called 'exampleorg/xmldata'. The name of the class should start with `Puppetx::<user>::<module>`,
  # e.g. 'Puppetx::Exampleorg::XmlData::XmlChecker" and
  # be located in `lib/puppetx/exampleorg/xml_data/xml_checker.rb`. The Puppet Binder will auto-load this file when it
  # has a binding to the class `Puppetx::Exampleorg::XmlData::XmlChecker'
  # The Ruby Module `Puppetx` is created by Puppet, the remaining modules should be created by the loaded logic - e.g.:
  #
  # @example Defining an XmlChecker
  #   module Puppetx::Exampleorg
  #     module XmlData
  #       class XmlChecker < Puppetx::Puppetlabs::SyntaxCheckers::SyntaxChecker
  #         def check(text, syntax_identifier, acceptor, location_hash)
  #            # do the checking
  #         end
  #       end
  #     end
  #   end
  #
  # Implementing the check method
  # -----------------------------
  # The implementation of the {#check} method should naturally perform syntax checking of the given text/string and
  # produce found issues on the given `acceptor`. These can be warnings or errors. The method should return `false` if
  # any warnings or errors were produced (it is up to the caller to check for error/warning conditions and report them
  # to the user).
  #
  # Issues are reported by calling the given `acceptor`, which takes a severity (e.g. `:error`,
  # or `:warning), an {Puppet::Pops::Issues::Issue} instance, and a {Puppet::Pops::Adapters::SourcePosAdapter}
  # (which describes details about linenumber, position, and length of the problem area). Note that the
  # `location_info` given to the check method holds information about the location of the string in its *container*
  # (e.g. the source position of a Heredoc); this information can be used if more detailed information is not
  # available, or combined if there are more details (relative to the start of the checked string).
  #
  # @example Reporting an issue
  #    # create an issue with a symbolic name (that can serve as a reference to more details about the problem),
  #    # make the name unique
  #    issue = Puppet::Pops::Issues::issue(:EXAMPLEORG_XMLDATA_ILLEGAL_XML) { "syntax error found in xml text" }
  #    source_pos = Puppet::Pops::Adapters::SourcePosAdapter.new()
  #    source_pos.line = info[:line] # use this if there is no detail from the used parser
  #    source_pos.pos = info[:pos]   # use this pos if there is no detail from used parser
  #
  #    # report it
  #    acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, info[:file], source_pos, {}))
  #
  # There is usually a cap on the number of errors/warnings that are presented to the user, this is handled by the
  # reporting logic, but care should be taken to not generate too many as the issues are kept in memory until
  # the checker returns. The acceptor may set a limit and simply ignore issues past a certain (high) number of reported
  # issues (this number is typically higher than the cap on issues reported to the user).
  #
  # The `syntax_identifier`
  # -----------------------
  # The extension makes use of a syntax identifier written in mime-style. This identifier can be something simple
  # as 'xml', or 'json', but can also consist of several segments joined with '+' where the most specific syntax variant
  # is placed first. When searching for a syntax checker; say for JSON having some special traits, say 'userdata', the
  # author of the text may indicate this as the text having the syntax "userdata+json" - when a checker is looked up it is
  # first checked if there is a checker for "userdata+json", if none is found, a lookup is made for "json" (since the text
  # must at least be valid json). The given identifier is passed to the checker (to allow the same checker to check for
  # several dialects/specializations).
  #
  # Use in Puppet DSL
  # -----------------
  # The Puppet DSL Heredoc support makes use of the syntax checker extension. A user of a
  # heredoc can specify the syntax in the heredoc tag, e.g.`@(END:userdata+json)`.
  #
  #
  # @abstract
  #
  class SyntaxChecker
    # Checks the text for syntax issues and reports them to the given acceptor.
    # This implementation is abstract, it raises {NotImplementedError} since a subclass should have implemented the
    # method.
    #
    # @param text [String] The text to check
    # @param syntax_identifier [String] The syntax identifier in mime style (e.g. 'json', 'json-patch+json', 'xml', 'myapp+xml'
    # @option location_info [String] :file The filename where the string originates
    # @option location_info [Integer] :line The line number identifying the location where the string is being used/checked
    # @option location_info [Integer] :position The position on the line identifying the location where the string is being used/checked
    # @return [Boolean] Whether the checked string had issues (warnings and/or errors) or not.
    # @api public
    #
    def check(text, syntax_identifier, acceptor, location_info)
      raise NotImplementedError, "The class #{self.class.name} should have implemented the method check()"
    end
  end
end
end
