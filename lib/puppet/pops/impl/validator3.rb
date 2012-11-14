# W.I.P 
# A Validator validates a model
# TODO: Instead of passing a model_name, use o and a label provider (to shorten and make human friendly names)
# TODO: Iterating model should set @current to the currently validated object (so it does not have to be passed around)
# 
class Puppet::Validator3
  attr_reader :visitor, :current
  attr_accessor :acceptor, :options
  class DefaultValidationOptions
    # Are hyphens allowed in a QualifiedName or not?
    def hyphen_in_name
      :error
    end
  end

  # TODO: Complete the implementation of this class
  # TODO: It should be in a separate file
  class DefaultValidationAxceptor
    def ignore(message, ast_object)
      # do nothing - better if call is avoided in the first place
    end

    def error(message, ast_object)
      # TODO: add error diagnostic
    end

    def warning(message, ast_object)
      # TODO: add warning diagnostic
    end
  end
  class DefaultLabelProvider
    def label_for(o) 
      o
    end
  end
  def initialize(acceptor = DefaultValidationAcceptor.new, options = DefaultValidationOptions.new, label_provider = DefaultLableProvider.new)
    @visitor = Visitor.new(self, "check", 1, 1)
    @acceptor = acceptor
    @options = options
  end

  def validate ast_object

  end

  def check_AssignmentExpression(o)
    # Can not assign to something in a differnet namespace
    #         raise Puppet::ParseError, "Cannot assign to variables in other namespaces" if val[0][:value] =~ /::/
    # Can not assign to indexes in arrays and hashes
    #
  end
  def check_AttributeOperation(o)
    # Validate that operation with :+> is contained in a ResourceOverride or Collector
    # 
  end
  def checkCollectExpression(o)
    # TODO: if a collect expresion tries to collect exported resources and storeconfigs is not on
    #   then it will not work... This was checked in the parser previously. This is a runtime checking
    #   thing as opposed to a language thing.
    #
    #   if args[:form] == :exported and ! Puppet[:storeconfigs]
    #     Puppet.warning addcontext("You cannot collect exported resources without storeconfigs being set; the collection will be ignored")
    #   end

  end
  def check_NodeDefinition(o)
    # Check that hostnames are valid hostnames (or regular expressons)
    # The 3.x checker only checks for illegal characters - if matching /[^-\w.]/ the name is invalid,
    # but this allows a name like "a..b......c", "----"
    # TODO: Implement host name validation - create a separate method for checking the actual string ? 
  end

  def check_Resource(o)
    # This is a runtime check - the model is valid, but will have runtime issues when evaluated
    # TODO: Consider having two different kinds of validation ?
    #
    #    if (type == :exported and ! Puppet[:storeconfigs])
    #      Puppet.warning addcontext("You cannot collect without storeconfigs being set")
    #    end
  end

  def check_ResourceDefaultsExpression(o)
    # TODO: Check that a ResourceDefaultsExpression is using the form :regular (or :nil).
    #      error "Defaults are not virtualizable" if val[1].is_a? AST::ResourceDefaults
  end
  # Asserts that value is a valid QualifiedName
  #--
  # Yes, this (almost) repeats what the lexer returns as a NAME token, but we are not certain the model
  # is created by the lexer. There are also validation options to control more detail.
  #
  def check_QualifiedName(o)
    s = o.value()
    if has_kind?(o, s, String) && has_pattern?(o, s, %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*})
      diagnose(o, @options.hypen_in_name, "A QualifiedName may not contain a hyphen ('-'): %s", s) {
        s.include?('-')
      }
    end
  end

  # Asserts that the value is a valid UpperCaseWord (a CLASSREF)
  #--
  # Yes this (almost) repeats what the lexer returns as a CLASSREF, but there is no guarantee that the model
  # was created by the lexer. There are also options.
  def check_QualifiedReference(o)
    s = o.value()
    if has_kind?(o, s, String) && has_pattern?(o, s, %r{((::){0,1}[A-Z][-\w]*)+})
      diagnose(o, @options.hypen_in_name, "A QualifiedReference may not contain a hyphen ('-'): %s", s) {
        s.include?('-')
      }
    end
  end

  def check_InstanceReference(o)
    # The type_name should be a QualifiedReference as opposed to a Qualified Name
    # TODO: Original warning is :
    #       Puppet.warning addcontext("Deprecation notice:  Resource references should now be capitalized")
  end
  
  def check_LiteralReqularExpression(o)
    r = o.value()
  end
  protected

  def check_CaseExpression o
    # There should only be one LiteralDefault case option value
    # TODO: Implement this check
  end
  
  # Checks and reports to the configured acceptor if the given value is not of the given kind
  def has_kind?(model, value, kind, model_name)
    return !diagnose(:error, "A %s must have a value that is a %s", model_name, kind) { value.kindOf? kind } 
  end
  
  # Checks and reports to the configured acceptor if the basic assumptions about the string value
  # are not true. Returns true if the given string s is not empty and conforms to the given regexp.
  # If empty, or not matching the regexp, errors are sent to the acceptor.
  #
  def has_pattern?(o, model, s, regexp, type)
    return !(diagnose(o, :error, "A #{type} can not be empty") { s.empty? } or diagnose(:error, "Not a valid #{type}: %s", s) { s !~ regexp })
  end

  def diagnose (o, option, message, messageArgs=[])
    if option != :ignore && yield
      @acceptor.send(option, message % messageArgs, o)
      true # positive outcome = not ignored and have the disease
    end
  end
end