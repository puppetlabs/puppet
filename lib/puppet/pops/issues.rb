# Defines classes to deal with issues, and message formatting and defines constants with Issues.
# @api public
#
module Puppet::Pops
module Issues
  # Describes an issue, and can produce a message for an occurrence of the issue.
  #
  class Issue
    # The issue code
    # @return [Symbol]
    attr_reader :issue_code

    # A block producing the message
    # @return [Proc]
    attr_reader :message_block

    # Names that must be bound in an occurrence of the issue to be able to produce a message.
    # These are the names in addition to requirements stipulated by the Issue formatter contract; i.e. :label`,
    # and `:semantic`.
    #
    attr_reader :arg_names

    # If this issue can have its severity lowered to :warning, :deprecation, or :ignored
    attr_writer :demotable
    # Configures the Issue with required arguments (bound by occurrence), and a block producing a message.
    def initialize issue_code, *args, &block
      @issue_code = issue_code
      @message_block = block
      @arg_names = args
      @demotable = true
    end

    # Returns true if it is allowed to demote this issue
    def demotable?
      @demotable
    end

    # Formats a message for an occurrence of the issue with argument bindings passed in a hash.
    # The hash must contain a LabelProvider bound to the key `label` and the semantic model element
    # bound to the key `semantic`. All required arguments as specified by `arg_names` must be bound
    # in the given `hash`.
    # @api public
    #
    def format(hash ={})
      # Create a Message Data where all hash keys become methods for convenient interpolation
      # in issue text.
      msgdata = MessageData.new(*arg_names)
      begin
        # Evaluate the message block in the msg data's binding
        msgdata.format(hash, &message_block)
      rescue StandardError => e
        raise RuntimeError, _("Error while reporting issue: %{code}. %{message}") % { code: issue_code, message: e.message }, caller
      end
    end
  end

  # A version of Issues that does not require MessageData's
  # metaprogramming. Does not support error time logic or
  # messages that require the label.
  class SimpleIssue < Issue
    def initialize(issue_code, template, demotable = true)
      @issue_code = issue_code
      @template = template
      @demotable = demotable
    end

    def format(data = {})
      _(@template) % data
    end
  end

  class DynamicIssue < Issue
    def initialize(issue_code, demotable = true, message_proc)
      @issue_code = issue_code
      @message_proc = message_proc
      @demotable = true
    end

    def format(data = {})
      @message_proc.call(data)
    end
  end

  # Provides a binding of arguments passed to Issue.format to method names available
  # in the issue's message producing block.
  # @api private
  #
  class MessageData
    def initialize *argnames
      singleton = class << self; self end
      argnames.each do |name|
        singleton.send(:define_method, name) do
          @data[name]
        end
      end
    end

    def format(hash, &block)
      @data = hash
      instance_eval(&block)
    end

    # Obtains the label provider given as a key `:label` in the hash passed to #format. The label provider is
    # return if no arguments are given. If given an argument, returns the result of calling #label on the label
    # provider.
    #
    # @param args [Object] one object to obtain a label for or zero arguments to obtain the label provider
    # @return [LabelProvider,String] the label provider or label depending on if an argument is given or not
    # @raise [Puppet::Error] if no label provider is found
    def label(*args)
      args.empty? ? label_provider : label_provider.label(args[0])
    end

    # Returns the label provider given as key `:label` in the hash passed to #format.
    # @return [LabelProvider] the label provider
    # @raise [Puppet::Error] if no label provider is found
    def label_provider
      label_provider = @data[:label]
      #TRANSLATORS ":label" is a keyword and should not be translated
      raise Puppet::Error, _('Label provider key :label must be set to produce the text of the message!') unless label_provider
      label_provider
    end

    # Returns the label provider given as a key in the hash passed to #format.
    #
    def semantic
      #TRANSLATORS ":semantic" is a keyword and should not be translated
      raise Puppet::Error, _('Label provider key :semantic must be set to produce the text of the message!') unless @data[:semantic]
      @data[:semantic]
    end
  end

  # Defines an issue with the given `issue_code`, additional required parameters, and a block producing a message.
  # The block is evaluated in the context of a MessageData which provides convenient access to all required arguments
  # via accessor methods. In addition to accessors for specified arguments, these are also available:
  # * `label` - a `LabelProvider` that provides human understandable names for model elements and production of article (a/an/the).
  # * `semantic` - the model element for which the issue is reported
  #
  # @param issue_code [Symbol] the issue code for the issue used as an identifier, should be the same as the constant
  #   the issue is bound to.
  # @param args [Symbol] required arguments that must be passed when formatting the message, may be empty
  # @param block [Proc] a block producing the message string, evaluated in a MessageData scope. The produced string
  #   should not end with a period as additional information may be appended.
  #
  # @see MessageData
  # @api public
  #
  def self.issue(issue_code, *args, &block)
    Issue.new(issue_code, *args, &block)
  end

  # Creates a non demotable issue.
  # @see Issue.issue
  #
  def self.hard_issue(issue_code, *args, &block)
    result = Issue.new(issue_code, *args, &block)
    result.demotable = false
    result
  end

  def self.simple_issue(issue_code, template)
    SimpleIssue.new(issue_code, template)
  end

  def self.simple_hard_issue(issue_code, template)
    SimpleIssue.new(issue_code, template, false)
  end

  def self.dynamic_issue(issue_code, &block)
    DynamicIssue.new(issue_code, block)
  end

  def self.dynamic_hard_issue(issue_code, &block)
    DynamicIssue.new(issue_code, false, block)
  end

  # @comment Here follows definitions of issues. The intent is to provide a list from which yardoc can be generated
  #   containing more detailed information / explanation of the issue.
  #   These issues are set as constants, but it is unfortunately not possible for the created object to easily know which
  #   name it is bound to. Instead the constant has to be repeated. (Alternatively, it could be done by instead calling
  #   #const_set on the module, but the extra work required to get yardoc output vs. the extra effort to repeat the name
  #   twice makes it not worth it (if doable at all, since there is no tag to artificially construct a constant, and
  #   the parse tag does not produce any result for a constant assignment).

  # This is allowed (3.1) and has not yet been deprecated.
  # @todo configuration
  #
  NAME_WITH_HYPHEN = dynamic_issue :NAME_WITH_HYPHEN do |data|
    _("%{issue} may not have a name containing a hyphen. The name '%{name}' is not legal") % { issue: data[:label].a_an_uc(data[:semantic]), name: data[:name] }
  end

  # When a variable name contains a hyphen and these are illegal.
  # It is possible to control if a hyphen is legal in a name or not using the setting TODO
  # @todo describe the setting
  # @api public
  # @todo configuration if this is error or warning
  #
  VAR_WITH_HYPHEN = simple_issue(:VAR_WITH_HYPHEN, "A variable name may not contain a hyphen. The name '%{name}' is not legal")

  # A class, definition, or node may only appear at top level or inside other classes
  # @todo Is this really true for nodes? Can they be inside classes? Isn't that too late?
  # @api public
  #
  NOT_TOP_LEVEL = simple_hard_issue(:NOT_TOP_LEVEL, "Classes, definitions, and nodes may only appear at toplevel or inside other classes")

  NOT_ABSOLUTE_TOP_LEVEL = dynamic_hard_issue :NOT_ABSOLUTE_TOP_LEVEL do |data|
    _("%{value} may only appear at toplevel") % { value: data[:label].a_an_uc(data[:semantic]) }
  end

  CROSS_SCOPE_ASSIGNMENT = simple_hard_issue(
    :CROSS_SCOPE_ASSIGNMENT,
    "Illegal attempt to assign to '%{name}'. Cannot assign to variables in other namespaces"
  )

  # Assignment can only be made to certain types of left hand expressions such as variables.
  ILLEGAL_ASSIGNMENT = dynamic_hard_issue :ILLEGAL_ASSIGNMENT do |data|
    _("Illegal attempt to assign to '%{value}'. Not an assignable reference") % { value: data[:label].a_an(data[:semantic]) }
  end

  # Variables are immutable, cannot reassign in the same assignment scope
  ILLEGAL_REASSIGNMENT = dynamic_hard_issue :ILLEGAL_REASSIGNMENT do |data|
    if Validation::Checker4_0::RESERVED_PARAMETERS[data[:name]]
      _("Cannot reassign built in (or already assigned) variable '$%{var}'") % { var: data[:name] }
    else
      _("Cannot reassign variable '$%{var}'") % { var: data[:name] }
    end
  end

  # Variables facts and trusted
  ILLEGAL_RESERVED_ASSIGNMENT = simple_hard_issue(
    :ILLEGAL_RESERVED_ASSIGNMENT,
    "Attempt to assign to a reserved variable name: '$%{name}'"
  )

  # Assignment cannot be made to numeric match result variables
  ILLEGAL_NUMERIC_ASSIGNMENT = simple_issue(
    :ILLEGAL_NUMERIC_ASSIGNMENT,
    "Illegal attempt to assign to the numeric match result variable '$%{varname}'. Numeric variables are not assignable"
  )

  # Assignment can only be made to certain types of left hand expressions such as variables.
  ILLEGAL_ASSIGNMENT_CONTEXT = simple_hard_issue(:ILLEGAL_ASSIGNMENT_CONTEXT, "Assignment not allowed here")

  # parameters cannot have numeric names, clashes with match result variables
  ILLEGAL_NUMERIC_PARAMETER = simple_issue(
    :ILLEGAL_NUMERIC_PARAMETER,
    "The numeric parameter name '$%{name}' cannot be used (clashes with numeric match result variables)"
  )

  # In certain versions of Puppet it may be allowed to assign to a not already assigned key
  # in an array or a hash. This is an optional validation that may be turned on to prevent accidental
  # mutation.
  #
  ILLEGAL_INDEXED_ASSIGNMENT = simple_issue(
    :ILLEGAL_INDEXED_ASSIGNMENT,
    "Illegal attempt to assign via [index/key]. Not an assignable reference"
  )

  # When indexed assignment ($x[]=) is allowed, the leftmost expression must be
  # a variable expression.
  #
  ILLEGAL_ASSIGNMENT_VIA_INDEX = dynamic_hard_issue :ILLEGAL_ASSIGNMENT_VIA_INDEX do |data|
    _("Illegal attempt to assign to %{value} via [index/key]. Not an assignable reference") % { value: data[:label].a_an(data[:semantic]) }
  end

  ILLEGAL_MULTI_ASSIGNMENT_SIZE = simple_hard_issue(
    :ILLEGAL_MULTI_ASSIGNMENT_SIZE,
    "Mismatched number of assignable entries and values, expected %{expected}, got %{actual}"
  )

  MISSING_MULTI_ASSIGNMENT_KEY = simple_hard_issue(
    :MISSING_MULTI_ASSIGNMENT_KEY,
    "No value for required key '%{key}' in assignment to variables from hash"
  )

  MISSING_MULTI_ASSIGNMENT_VARIABLE = simple_hard_issue(
    :MISSING_MULTI_ASSIGNMENT_VARIABLE,
    "No value for required variable '$%{name}' in assignment to variables from class reference"
  )

  APPENDS_DELETES_NO_LONGER_SUPPORTED = simple_hard_issue(
    :APPENDS_DELETES_NO_LONGER_SUPPORTED,
    "The operator '%{operator}' is no longer supported. See http://links.puppet.com/remove-plus-equals"
  )

  # For unsupported operators (e.g. += and -= in puppet 4).
  #
  UNSUPPORTED_OPERATOR = simple_hard_issue(
    :UNSUPPORTED_OPERATOR,
    "The operator '%{operator}' is not supported."
  )

  # For operators that are not supported in specific contexts (e.g. '* =>' in
  # resource defaults)
  #
  UNSUPPORTED_OPERATOR_IN_CONTEXT = dynamic_hard_issue :UNSUPPORTED_OPERATOR_IN_CONTEXT do |data|
    _("The operator '%{operator}' in %{value} is not supported.") % { operator: data[:operator], value: data[:label].a_an(data[:semantic]) }
  end

  # For non applicable operators (e.g. << on Hash).
  #
  OPERATOR_NOT_APPLICABLE = dynamic_hard_issue :OPERATOR_NOT_APPLICABLE do |data|
    _("Operator '%{operator}' is not applicable to %{left}.") % { operator: data[:operator], left: data[:label].a_an(data[:left_value]) }
  end

  OPERATOR_NOT_APPLICABLE_WHEN = dynamic_hard_issue :OPERATOR_NOT_APPLICABLE_WHEN do |data|
    _("Operator '%{operator}' is not applicable to %{left} when right side is %{right}.") % { operator: data[:operator], left: data[:label].a_an(data[:left_value]), right: data[:label].a_an(data[:right_value]) }
  end

  COMPARISON_NOT_POSSIBLE = dynamic_hard_issue :COMPARISON_NOT_POSSIBLE do |data|
    _("Comparison of: %{left} %{operator} %{right}, is not possible. Caused by '%{detail}'.") % { left: data[:label].label(data[:left_value]), operator: data[:operator], right: data[:label].label(data[:right_value]), detail: data[:detail] }
  end

  MATCH_NOT_REGEXP = simple_hard_issue(
    :MATCH_NOT_REGEXP,
    "Can not convert right match operand to a regular expression. Caused by '%{detail}'."
  )

  MATCH_NOT_STRING = dynamic_hard_issue :MATCH_NOT_STRING do |data|
    _("Left match operand must result in a String value. Got %{left}.") % { left: data[:label].a_an(data[:left_value]) }
  end

  # Some expressions/statements may not produce a value (known as right-value, or rvalue).
  # This may vary between puppet versions.
  #
  NOT_RVALUE = dynamic_issue :NOT_RVALUE do |data|
    _("Invalid use of expression. %{value} does not produce a value") % { value: data[:label].a_an_uc(data[:semantic]) }
  end

  # Appending to attributes is only allowed in certain types of resource expressions.
  #
  ILLEGAL_ATTRIBUTE_APPEND = dynamic_hard_issue :ILLEGAL_ATTRIBUTE_APPEND do |data|
    _("Illegal +> operation on attribute %{attr}. This operator can not be used in %{expression}") % { attr: data[:name], expression: data[:label].a_an(data[:parent]) }
  end

  ILLEGAL_NAME = simple_hard_issue(
    :ILLEGAL_NAME,
    "Illegal name. The given name '%{name}' does not conform to the naming rule /^((::)?[a-z_]\w*)(::[a-z]\\w*)*$/"
  )

  ILLEGAL_SINGLE_TYPE_MAPPING = dynamic_hard_issue :ILLEGAL_TYPE_MAPPING do |data|
    _("Illegal type mapping. Expected a Type on the left side, got %{expression}") % { expression: data[:label].a_an_uc(data[:semantic]) }
  end

  ILLEGAL_REGEXP_TYPE_MAPPING = dynamic_hard_issue :ILLEGAL_TYPE_MAPPING do |data|
    _("Illegal type mapping. Expected a Tuple[Regexp,String] on the left side, got %{expression}") % { expression: data[:label].a_an_uc(data[:semantic]) }
  end

  ILLEGAL_PARAM_NAME = simple_hard_issue(
    :ILLEGAL_PARAM_NAME,
    "Illegal parameter name. The given name '%{name}' does not conform to the naming rule /^[a-z_]\\w*$/"
  )

  ILLEGAL_VAR_NAME = simple_hard_issue(
    :ILLEGAL_VAR_NAME,
    "Illegal variable name, The given name '%{name}' does not conform to the naming rule /^((::)?[a-z]\\w*)*((::)?[a-z_]\\w*)$/"
  )

  ILLEGAL_NUMERIC_VAR_NAME = simple_hard_issue(
    :ILLEGAL_NUMERIC_VAR_NAME,
    "Illegal numeric variable name, The given name '%{name}' must be a decimal value if it starts with a digit 0-9"
  )

  # In case a model is constructed programmatically, it must create valid type references.
  #
  ILLEGAL_CLASSREF = simple_hard_issue(
    :ILLEGAL_CLASSREF,
    "Illegal type reference. The given name '%{name}' does not conform to the naming rule"
  )

  # This is a runtime issue - storeconfigs must be on in order to collect exported. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS = simple_issue(
    :RT_NO_STORECONFIGS,
    "You cannot collect exported resources without storeconfigs being set; the collection will be ignored"
  )

  # This is a runtime issue - storeconfigs must be on in order to export a resource. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS_EXPORT = simple_issue(
    :RT_NO_STORECONFIGS_EXPORT,
    "You cannot collect exported resources without storeconfigs being set; the export is ignored"
  )

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_CHARS = simple_hard_issue(
    :ILLEGAL_HOSTNAME_CHARS,
    "The hostname '%{hostname}' contains illegal characters (only letters, digits, '_', '-', and '.' are allowed)"
  )

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_INTERPOLATION = simple_hard_issue(
    :ILLEGAL_HOSTNAME_INTERPOLATION,
    "An interpolated expression is not allowed in a hostname of a node"
  )

  # Issues when an expression is used where it is not legal.
  # E.g. an arithmetic expression where a hostname is expected.
  #
  ILLEGAL_EXPRESSION = dynamic_hard_issue :ILLEGAL_EXPRESSION do |data|
    _("Illegal expression. %{expression} is unacceptable as %{feature} in %{container}") % { expression: data[:label].a_an_uc(data[:semantic]), feature: data[:feature], container: data[:label].a_an(data[:container]) }
  end

  # Issues when a variable is not a NAME
  #
  ILLEGAL_VARIABLE_EXPRESSION = dynamic_hard_issue :ILLEGAL_VARIABLE_EXPRESSION do |data|
    _("Illegal variable expression. %{expression} did not produce a variable name (String or Numeric).") % { expression: data[:label].a_an_uc(data[:semantic]) }
  end

  # Issues when an expression is used illegally in a query.
  # query only supports == and !=, and not <, > etc.
  #
  ILLEGAL_QUERY_EXPRESSION = dynamic_hard_issue :ILLEGAL_QUERY_EXPRESSION do |data|
    _("Illegal query expression. %{expression} cannot be used in a query") % { expression: data[:label].a_an_uc(data[:semantic]) }
  end

  # If an attempt is made to make a resource default virtual or exported.
  #
  NOT_VIRTUALIZEABLE = simple_hard_issue(
    :NOT_VIRTUALIZEABLE,
    "Resource Defaults are not virtualizable"
  )

  CLASS_NOT_VIRTUALIZABLE = simple_issue(
    :CLASS_NOT_VIRTUALIZABLE,
    "Classes are not virtualizable"
  )

  # When an attempt is made to use multiple keys (to produce a range in Ruby - e.g. $arr[2,-1]).
  # This is not supported in 3x, but it allowed in 4x.
  #
  UNSUPPORTED_RANGE = dynamic_issue :UNSUPPORTED_RANGE do |data|
    _("Attempt to use unsupported range in %{expression}, %{count} values given for max 1") % { expression: data[:label].a_an(data[:semantic]), count: data[:count] }
  end

  # Issues when expressions that are not implemented or activated in the current version are used.
  #
  UNSUPPORTED_EXPRESSION = dynamic_issue :UNSUPPORTED_EXPRESSION do |data|
    _("Expressions of type %{expression} are not supported in this version of Puppet") % { expression: data[:label].a_an(data[:semantic]) }
  end

  ILLEGAL_RELATIONSHIP_OPERAND_TYPE = dynamic_issue :ILLEGAL_RELATIONSHIP_OPERAND_TYPE do |data|
    _("Illegal relationship operand, can not form a relationship with %{expression}. A Catalog type is required.") % { expression: data[:label].a_an(data[:operand]) }
  end

  NOT_CATALOG_TYPE = simple_issue(
    :NOT_CATALOG_TYPE,
    "Illegal relationship operand, can not form a relationship with something of type %{type}. A Catalog type is required."
  )

  BAD_STRING_SLICE_ARITY = simple_issue(
    :BAD_STRING_SLICE_ARITY,
    "String supports [] with one or two arguments. Got %{actual}"
  )

  BAD_STRING_SLICE_TYPE = simple_issue(
    :BAD_STRING_SLICE_TYPE,
    "String-Type [] requires all arguments to be integers (or default). Got %{actual}"
  )

  BAD_ARRAY_SLICE_ARITY = simple_issue(
    :BAD_ARRAY_SLICE_ARITY,
    "Array supports [] with one or two arguments. Got %{actual}"
  )

  BAD_HASH_SLICE_ARITY = simple_issue(
    :BAD_HASH_SLICE_ARITY,
    "Hash supports [] with one or more arguments. Got %{actual}"
  )

  BAD_INTEGER_SLICE_ARITY = simple_issue(
    :BAD_INTEGER_SLICE_ARITY,
    "Integer-Type supports [] with one or two arguments (from, to). Got %{actual}"
  )

  BAD_INTEGER_SLICE_TYPE = simple_issue(
    :BAD_INTEGER_SLICE_TYPE,
    "Integer-Type [] requires all arguments to be integers (or default). Got %{actual}"
  )

  BAD_COLLECTION_SLICE_TYPE = dynamic_issue :BAD_COLLECTION_SLICE_TYPE do |data|
    _("A Type's size constraint arguments must be a single Integer type, or 1-2 integers (or default). Got %{actual}") % { actual: data[:label].a_an(data[:actual]) }
  end

  BAD_FLOAT_SLICE_ARITY = simple_issue(
    :BAD_INTEGER_SLICE_ARITY,
    "Float-Type supports [] with one or two arguments (from, to). Got %{actual}"
  )

  BAD_FLOAT_SLICE_TYPE = simple_issue(
    :BAD_INTEGER_SLICE_TYPE,
    "Float-Type [] requires all arguments to be floats, or integers (or default). Got %{actual}"
  )

  BAD_SLICE_KEY_TYPE = dynamic_issue :BAD_SLICE_KEY_TYPE do |data|
    expected_text = if data[:expected_classes].size > 1
      _("one of %{expected} are") % { expected: data[:expected_classes].join(', ') }
    else
      _("%{expected} is") % { expected: data[:expected_classes][0] }
    end
    _("%{expression}[] cannot use %{actual} where %{expected_text} expected") % { expression: data[:label].a_an_uc(data[:left_value]), actual: data[:actual], expected_text: expected_text }
  end

  BAD_STRING_SLICE_KEY_TYPE = dynamic_issue :BAD_STRING_SLICE_KEY_TYPE do |data|
    _("A substring operation does not accept %{label_article} %{actual_type} as a character index. Expected an Integer") % { label_article: data[:label].article(data[:actual_type]), actual_type: data[:actual_type] }
  end

  BAD_NOT_UNDEF_SLICE_TYPE = simple_issue(
    :BAD_NOT_UNDEF_SLICE_TYPE,
    "%{base_type}[] argument must be a Type or a String. Got %{actual}"
  )

  BAD_TYPE_SLICE_TYPE = simple_issue(
    :BAD_TYPE_SLICE_TYPE,
    "%{base_type}[] arguments must be types. Got %{actual}"
  )

  BAD_TYPE_SLICE_ARITY = dynamic_issue :BAD_TYPE_SLICE_ARITY do |data|
    base_type_label = data[:base_type].is_a?(String) ? data[:base_type] : data[:label].a_an_uc(data[:base_type])
    if data[:max] == -1 || data[:max] == Float::INFINITY
      _("%{base_type_label}[] accepts %{min} or more arguments. Got %{actual}") % { base_type_label: base_type_label, min: data[:min], actual: data[:actual] }
    elsif data[:max] && data[:max] != data[:min]
      _("%{base_type_label}[] accepts %{min} to %{max} arguments. Got %{actual}") % { base_type_label: base_type_label, min: data[:min], max: data[:max], actual: data[:actual] }
    else
      _("%{base_type_label}[] accepts %{min} %{label}. Got %{actual}") % { base_type_label: base_type_label, min: data[:min], label: data[:label].plural_s(data[:min], _('argument')), actual: data[:actual] }
    end
  end

  BAD_TYPE_SPECIALIZATION = dynamic_hard_issue :BAD_TYPE_SPECIALIZATION do |data|
    _("Error creating type specialization of %{base_type}, %{message}") % { base_type: data[:label].a_an(data[:type]), message: data[:message] }
  end

  ILLEGAL_TYPE_SPECIALIZATION = simple_issue(
    :ILLEGAL_TYPE_SPECIALIZATION,
    "Cannot specialize an already specialized %{kind} type"
  )

  ILLEGAL_RESOURCE_SPECIALIZATION = simple_issue(
    :ILLEGAL_RESOURCE_SPECIALIZATION,
    "First argument to Resource[] must be a resource type or a String. Got %{actual}."
  )

  EMPTY_RESOURCE_SPECIALIZATION = simple_issue(
    :EMPTY_RESOURCE_SPECIALIZATION,
    "Arguments to Resource[] are all empty/undefined"
  )

  ILLEGAL_HOSTCLASS_NAME = dynamic_hard_issue :ILLEGAL_HOSTCLASS_NAME do |data|
    _("Illegal Class name in class reference. %{expression} cannot be used where a String is expected") % { expression: data[:label].a_an_uc(data[:name]) }
  end

  ILLEGAL_DEFINITION_NAME = dynamic_hard_issue :ILLEGAL_DEFINITION_NAME do |data|
    _("Unacceptable name. The name '%{name}' is unacceptable as the name of %{value}") % { name: data[:name], value: data[:label].a_an(data[:semantic]) }
  end

  ILLEGAL_DEFINITION_LOCATION = simple_issue(
    :ILLEGAL_DEFINITION_LOCATION,
    "Unacceptable location. The name '%{name}' is unacceptable in file '%{file}'"
  )

  ILLEGAL_TOP_CONSTRUCT_LOCATION = dynamic_issue :ILLEGAL_TOP_CONSTRUCT_LOCATION do |data|
    if data[:semantic].is_a?(Puppet::Pops::Model::NamedDefinition)
      _("The %{value} '%{name}' is unacceptable as a top level construct in this location") % { name: data[:semantic].name, value: data[:label].label(data[:semantic]) }
    else
      _("This %{value} is unacceptable as a top level construct in this location") % { value: data[:label].label(data[:semantic]) }
    end
  end

  CAPTURES_REST_NOT_LAST = simple_hard_issue(
    :CAPTURES_REST_NOT_LAST,
    "Parameter $%{param_name} is not last, and has 'captures rest'"
  )

  CAPTURES_REST_NOT_SUPPORTED = dynamic_hard_issue :CAPTURES_REST_NOT_SUPPORTED do |data|
    _("Parameter $%{param} has 'captures rest' - not supported in %{container}") % { param: data[:param_name], container: data[:label].a_an(data[:container]) }
  end

  REQUIRED_PARAMETER_AFTER_OPTIONAL = simple_hard_issue(
    :REQUIRED_PARAMETER_AFTER_OPTIONAL,
    "Parameter $%{param_name} is required but appears after optional parameters"
  )

  MISSING_REQUIRED_PARAMETER = simple_hard_issue(
    :MISSING_REQUIRED_PARAMETER,
    "Parameter $%{param_name} is required but no value was given"
  )

  NOT_NUMERIC = simple_issue(:NOT_NUMERIC, "The value '%{value}' cannot be converted to Numeric.")

  NUMERIC_COERCION = simple_issue(
    :NUMERIC_COERCION,
    "The string '%{before}' was automatically coerced to the numerical value %{after}"
  )

  UNKNOWN_FUNCTION = simple_issue(:UNKNOWN_FUNCTION, "Unknown function: '%{name}'.")

  UNKNOWN_VARIABLE = simple_issue(:UNKNOWN_VARIABLE, "Unknown variable: '%{name}'.")

  RUNTIME_ERROR = dynamic_issue :RUNTIME_ERROR do |data|
    _("Error while evaluating %{expression}, %{detail}") % { expression: data[:label].a_an(data[:semantic]), detail: data[:detail] }
  end

  UNKNOWN_RESOURCE_TYPE = simple_issue(
    :UNKNOWN_RESOURCE_TYPE,
    "Resource type not found: %{type_name}"
  )

  ILLEGAL_RESOURCE_TYPE = simple_hard_issue(
    :ILLEGAL_RESOURCE_TYPE,
    "Illegal Resource Type expression, expected result to be a type name, or untitled Resource, got %{actual}"
  )

  DUPLICATE_TITLE = simple_issue(
    :DUPLICATE_TITLE,
    "The title '%{title}' has already been used in this resource expression"
  )

  DUPLICATE_ATTRIBUTE = simple_issue(
    :DUPLICATE_ATTRIBUE,
    "The attribute '%{attribute}' has already been set"
  )

  MISSING_TITLE = simple_hard_issue(:MISSING_TITLE, "Missing title. The title expression resulted in undef")

  MISSING_TITLE_AT = simple_hard_issue(
    :MISSING_TITLE_AT,
    "Missing title at index %{index}. The title expression resulted in an undef title"
  )

  ILLEGAL_TITLE_TYPE_AT = simple_hard_issue(
    :ILLEGAL_TITLE_TYPE_AT,
    "Illegal title type at index %{index}. Expected String, got %{actual}"
  )

  EMPTY_STRING_TITLE_AT = simple_hard_issue(
    :EMPTY_STRING_TITLE_AT,
    "Empty string title at %{index}. Title strings must have a length greater than zero."
  )

  UNKNOWN_RESOURCE = simple_issue(
    :UNKNOWN_RESOURCE,
    "Resource not found: %{type_name}['%{title}']"
  )

  UNKNOWN_RESOURCE_PARAMETER = dynamic_issue :UNKNOWN_RESOURCE_PARAMETER do |data|
    _("The resource %{type_name}['%{title}'] does not have a parameter called '%{param}'") % { type_name: data[:type_name].capitalize, title: data[:title], param: data[:param_name] }
  end

  DIV_BY_ZERO = simple_hard_issue(:DIV_BY_ZERO, "Division by 0")

  RESULT_IS_INFINITY = simple_hard_issue(
    :RESULT_IS_INFINITY,
    "The result of the %{operator} expression is Infinity"
  )

  # TODO_HEREDOC
  EMPTY_HEREDOC_SYNTAX_SEGMENT = simple_issue(
    :EMPTY_HEREDOC_SYNTAX_SEGMENT,
    "Heredoc syntax specification has empty segment between '+' : '%{syntax}'"
  )

  ILLEGAL_EPP_PARAMETERS = simple_issue(
    :ILLEGAL_EPP_PARAMETERS,
    "Ambiguous EPP parameter expression. Probably missing '<%-' before parameters to remove leading whitespace"
  )

  DISCONTINUED_IMPORT = simple_hard_issue(
    :DISCONTINUED_IMPORT,
    #TRANSLATORS "import" is a function name and should not be translated
    "Use of 'import' has been discontinued in favor of a manifest directory. See http://links.puppet.com/puppet-import-deprecation"
  )

  IDEM_EXPRESSION_NOT_LAST = dynamic_issue :IDEM_EXPRESSION_NOT_LAST do |data|
    _("This %{expression} has no effect. A value was produced and then forgotten (one or more preceding expressions may have the wrong form)") % { expression: data[:label].label(data[:semantic]) }
  end

  RESOURCE_WITHOUT_TITLE = simple_issue(
    :RESOURCE_WITHOUT_TITLE,
    "This expression is invalid. Did you try declaring a '%{name}' resource without a title?"
  )

  IDEM_NOT_ALLOWED_LAST = dynamic_hard_issue :IDEM_NOT_ALLOWED_LAST do |data|
    _("This %{expression} has no effect. %{container} can not end with a value-producing expression without other effect") % { expression: data[:label].label(data[:semantic]), container: data[:label].a_an_uc(data[:container]) }
  end

  RESERVED_WORD = simple_hard_issue(
    :RESERVED_WORD,
    "Use of reserved word: %{word}, must be quoted if intended to be a String value"
  )

  FUTURE_RESERVED_WORD = simple_issue(
    :FUTURE_RESERVED_WORD,
    "Use of future reserved word: '%{word}'"
  )

  RESERVED_TYPE_NAME = dynamic_hard_issue :RESERVED_TYPE_NAME do |data|
    _("The name: '%{name}' is already defined by Puppet and can not be used as the name of %{expression}.") % { name: data[:name], expression: data[:label].a_an(data[:semantic]) }
  end

  UNMATCHED_SELECTOR = simple_hard_issue(
    :UNMATCHED_SELECTOR,
    "No matching entry for selector parameter with value '%{param_value}'"
  )

  ILLEGAL_NODE_INHERITANCE = simple_issue(
    :ILLEGAL_NODE_INHERITANCE,
    "Node inheritance is not supported in Puppet >= 4.0.0. See http://links.puppet.com/puppet-node-inheritance-deprecation"
  )

  ILLEGAL_OVERRIDDEN_TYPE = dynamic_issue :ILLEGAL_OVERRIDDEN_TYPE do |data|
    _("Resource Override can only operate on resources, got: %{actual}") % { actual: data[:label].label(data[:actual]) }
  end

  DUPLICATE_PARAMETER = simple_hard_issue(
    :DUPLICATE_PARAMETER,
    "The parameter '%{param_name}' is declared more than once in the parameter list"
  )

  DUPLICATE_KEY = simple_issue(:DUPLICATE_KEY, "The key '%{key}' is declared more than once")

  DUPLICATE_DEFAULT = dynamic_hard_issue :DUPLICATE_DEFAULT do |data|
    _("This %{container} already has a 'default' entry - this is a duplicate") % { container: data[:label].label(data[:container]) }
  end

  RESERVED_PARAMETER = dynamic_hard_issue :RESERVED_PARAMETER do |data|
    _("The parameter $%{param} redefines a built in parameter in %{container}") % { param: data[:param_name], container: data[:label].the(data[:container]) }
  end

  TYPE_MISMATCH = simple_hard_issue(
    :TYPE_MISMATCH,
    "Expected value of type %{expected}, got %{actual}"
  )

  MULTIPLE_ATTRIBUTES_UNFOLD = simple_hard_issue(
    :MULTIPLE_ATTRIBUTES_UNFOLD,
    "Unfolding of attributes from Hash can only be used once per resource body"
  )

  ILLEGAL_CATALOG_RELATED_EXPRESSION = dynamic_hard_issue :ILLEGAL_CATALOG_RELATED_EXPRESSION do |data|
    _("This %{expression} appears in a context where catalog related expressions are not allowed") % { expression: data[:label].label(data[:semantic]) }
  end

  SYNTAX_ERROR = simple_hard_issue(:SYNTAX_ERROR, "Syntax error at %{where}")

  ILLEGAL_CLASS_REFERENCE = simple_hard_issue(:ILLEGAL_CLASS_REFERENCE, 'Illegal class reference')

  ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE = simple_hard_issue(
    :ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE,
    'Illegal fully qualified class reference'
  )

  ILLEGAL_FULLY_QUALIFIED_NAME = simple_hard_issue(
    :ILLEGAL_FULLY_QUALIFIED_NAME,
    'Illegal fully qualified name'
  )

  ILLEGAL_NAME_OR_BARE_WORD = simple_hard_issue(
    :ILLEGAL_NAME_OR_BARE_WORD,
    'Illegal name or bare word'
  )

  ILLEGAL_NUMBER = simple_hard_issue(:ILLEGAL_NUMBER, "Illegal number '%{value}'")

  ILLEGAL_UNICODE_ESCAPE = simple_issue(
    :ILLEGAL_UNICODE_ESCAPE,
    "Unicode escape '\\u' was not followed by 4 hex digits or 1-6 hex digits in {} or was > 10ffff"
  )

  INVALID_HEX_NUMBER = simple_hard_issue(
    :INVALID_HEX_NUMBER,
    "Not a valid hex number %{value}"
  )

  INVALID_OCTAL_NUMBER = simple_hard_issue(
    :INVALID_OCTAL_NUMBER,
    "Not a valid octal number %{value}"
  )

  INVALID_DECIMAL_NUMBER = simple_hard_issue(
    :INVALID_DECIMAL_NUMBER,
    "Not a valid decimal number %{value}"
  )

  NO_INPUT_TO_LEXER = simple_hard_issue(
    :NO_INPUT_TO_LEXER,
    "Internal Error: No string or file given to lexer to process."
  )

  UNRECOGNIZED_ESCAPE = simple_issue(
    :UNRECOGNIZED_ESCAPE,
    "Unrecognized escape sequence '\\%{ch}'"
  )

  UNCLOSED_QUOTE = simple_hard_issue(
    :UNCLOSED_QUOTE,
    "Unclosed quote after %{after} followed by '%{followed_by}'"
  )

  UNCLOSED_MLCOMMENT = simple_hard_issue(:UNCLOSED_MLCOMMENT, 'Unclosed multiline comment')

  EPP_INTERNAL_ERROR = simple_hard_issue(
    :EPP_INTERNAL_ERROR,
    "Internal error: %{error}"
  )

  EPP_UNBALANCED_TAG = simple_hard_issue(
    :EPP_UNBALANCED_TAG,
    'Unbalanced epp tag, reached <eof> without closing tag.'
  )

  EPP_UNBALANCED_COMMENT = simple_hard_issue(
    :EPP_UNBALANCED_COMMENT,
    'Reaching end after opening <%%# without seeing %%>'
  )

  EPP_UNBALANCED_EXPRESSION = simple_hard_issue(
    :EPP_UNBALANCED_EXPRESSION,
    'Unbalanced embedded expression - opening <%% and reaching end of input'
  )

  HEREDOC_UNCLOSED_PARENTHESIS = simple_hard_issue(
    :HEREDOC_UNCLOSED_PARENTHESIS,
    "Unclosed parenthesis after '@(' followed by '%{followed_by}'"
  )

  HEREDOC_WITHOUT_END_TAGGED_LINE = simple_hard_issue(
    :HEREDOC_WITHOUT_END_TAGGED_LINE,
    'Heredoc without end-tagged line'
  )

  HEREDOC_INVALID_ESCAPE = simple_hard_issue(
    :HEREDOC_INVALID_ESCAPE,
    "Invalid heredoc escape char. Only t, r, n, s,  u, L, $ allowed. Got '%{actual}'"
  )

  HEREDOC_INVALID_SYNTAX = simple_hard_issue(
    :HEREDOC_INVALID_SYNTAX,
    'Invalid syntax in heredoc expected @(endtag[:syntax][/escapes])'
  )

  HEREDOC_WITHOUT_TEXT = simple_hard_issue(
    :HEREDOC_WITHOUT_TEXT,
    'Heredoc without any following lines of text'
  )

  HEREDOC_EMPTY_ENDTAG = simple_hard_issue(:HEREDOC_EMPTY_ENDTAG, 'Heredoc with an empty endtag')

  HEREDOC_MULTIPLE_AT_ESCAPES = dynamic_hard_issue :HEREDOC_MULTIPLE_AT_ESCAPES do |data|
    _("An escape char for @() may only appear once. Got '%{escapes}'") % { escapes: data[:escapes].join(', ') }
  end

  HEREDOC_DIRTY_MARGIN = simple_hard_issue(
    :HEREDOC_DIRTY_MARGIN,
    "Heredoc with text in the margin is not allowed (line %{heredoc_line} in this heredoc)"
  )

  ILLEGAL_BOM = simple_hard_issue(
    :ILLEGAL_BOM,
    "Illegal %{format_name} Byte Order mark at beginning of input: %{bytes} - remove these from the puppet source"
  )

  NO_SUCH_FILE_OR_DIRECTORY = simple_hard_issue(
    :NO_SUCH_FILE_OR_DIRECTORY,
    'No such file or directory: %{file}'
  )

  NOT_A_FILE = simple_hard_issue(:NOT_A_FILE, '%{file} is not a file')

  NUMERIC_OVERFLOW = dynamic_hard_issue :NUMERIC_OVERFLOW do |data|
    if data[:value] > 0
      _("%{expression} resulted in a value outside of Puppet Integer max range, got '%{value}'") % { expression: data[:label].a_an_uc(data[:semantic]), value: ("%#+x" % data[:value]) }
    else
      _("%{expression} resulted in a value outside of Puppet Integer min range, got '%{value}'") % { expression: data[:label].a_an_uc(data[:semantic]), value: ("%#+x" % data[:value]) }
    end
  end

  HIERA_UNSUPPORTED_VERSION = simple_hard_issue(
    :HIERA_UNSUPPORTED_VERSION,
    "This runtime does not support hiera.yaml version %{version}"
  )

  HIERA_VERSION_3_NOT_GLOBAL = dynamic_hard_issue :HIERA_VERSION_3_NOT_GLOBAL do |data|
    _("hiera.yaml version 3 cannot be used in %{location}") % { location: data[:label].a_an(data[:where]) }
  end

  HIERA_UNSUPPORTED_VERSION_IN_GLOBAL = simple_hard_issue(
    :HIERA_UNSUPPORTED_VERSION_IN_GLOBAL,
    'hiera.yaml version 4 cannot be used in the global layer'
  )

  HIERA_UNDEFINED_VARIABLE = simple_hard_issue(
    :HIERA_UNDEFINED_VARIABLE,
    "Undefined variable '%{name}'"
  )

  HIERA_BACKEND_MULTIPLY_DEFINED = dynamic_hard_issue :HIERA_BACKEND_MULTIPLY_DEFINED do |data|
    msg = _("Backend '%{name}' is defined more than once.") % { name: data[:name] }
    fl = data[:first_line]
    if fl
      msg += ' ' + _("First defined at %{error_location}") % { error_location: Puppet::Util::Errors.error_location(nil, fl) }
    end
    msg
  end

  HIERA_NO_PROVIDER_FOR_BACKEND = simple_hard_issue(
    :HIERA_NO_PROVIDER_FOR_BACKEND,
    "No data provider is registered for backend '%{name}'"
  )

  HIERA_HIERARCHY_NAME_MULTIPLY_DEFINED = dynamic_hard_issue :HIERA_HIERARCHY_NAME_MULTIPLY_DEFINED do |data|
    msg = _("Hierarchy name '%{name}' defined more than once.") % { name: data[:name] }
    fl = data[:first_line]
    if fl
      msg += ' ' + _("First defined at %{error_location}") % { error_location: Puppet::Util::Errors.error_location(nil, fl) }
    end
    msg
  end

  HIERA_V3_BACKEND_NOT_GLOBAL = simple_hard_issue(
    :HIERA_V3_BACKEND_NOT_GLOBAL,
    "'hiera3_backend' is only allowed in the global layer"
  )

  HIERA_DEFAULT_HIERARCHY_NOT_IN_MODULE = simple_hard_issue(
    :HIERA_DEFAULT_HIERARCHY_NOT_IN_MODULE,
    "'default_hierarchy' is only allowed in the module layer"
  )

  HIERA_V3_BACKEND_REPLACED_BY_DATA_HASH = simple_hard_issue(
    :HIERA_V3_BACKEND_REPLACED_BY_DATA_HASH,
    "Use \"data_hash: %{function_name}_data\" instead of \"hiera3_backend: %{function_name}\""
  )

  HIERA_MISSING_DATA_PROVIDER_FUNCTION = dynamic_hard_issue :HIERA_MISSING_DATA_PROVIDER_FUNCTION do |data|
    _("One of %{keys} must be defined in hierarchy '%{name}'") % { keys: data[:label].combine_strings(Lookup::HieraConfig::FUNCTION_KEYS), name: data[:name] }
  end

  HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS = dynamic_hard_issue :HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS do |data|
    _("Only one of %{keys} can be defined in hierarchy '%{name}'") % { keys: data[:label].combine_strings(Lookup::HieraConfig::FUNCTION_KEYS), name: data[:name] }
  end

  HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS_IN_DEFAULT = dynamic_hard_issue :HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS_IN_DEFAULT do |data|
    _("Only one of %{keys} can be defined in defaults") % { keys: data[:label].combine_strings(Lookup::HieraConfig::FUNCTION_KEYS) }
  end

  HIERA_MULTIPLE_LOCATION_SPECS = dynamic_hard_issue :HIERA_MULTIPLE_LOCATION_SPECS do |data|
    _("Only one of %{keys} can be defined in hierarchy '%{name}'") % { keys: data[:label].combine_strings(Lookup::HieraConfig::LOCATION_KEYS), name: data[:name] }
  end

  HIERA_OPTION_RESERVED_BY_PUPPET = simple_hard_issue(
    :HIERA_OPTION_RESERVED_BY_PUPPET,
    "Option key '%{key}' used in hierarchy '%{name}' is reserved by Puppet"
  )

  HIERA_DEFAULT_OPTION_RESERVED_BY_PUPPET = simple_hard_issue(
    :HIERA_DEFAULT_OPTION_RESERVED_BY_PUPPET,
    "Option key '%{key}' used in defaults is reserved by Puppet"
  )

  HIERA_DATA_PROVIDER_FUNCTION_NOT_FOUND = simple_hard_issue(
    :HIERA_DATA_PROVIDER_FUNCTION_NOT_FOUND,
    "Unable to find '%{function_type}' function named '%{function_name}'"
  )

  HIERA_INTERPOLATION_ALIAS_NOT_ENTIRE_STRING = simple_hard_issue(
    :HIERA_INTERPOLATION_ALIAS_NOT_ENTIRE_STRING,
    "'alias' interpolation is only permitted if the expression is equal to the entire string"
  )

  HIERA_INTERPOLATION_UNKNOWN_INTERPOLATION_METHOD = simple_hard_issue(
    :HIERA_INTERPOLATION_UNKNOWN_INTERPOLATION_METHOD,
    "Unknown interpolation method '%{name}'"
  )

  HIERA_INTERPOLATION_METHOD_SYNTAX_NOT_ALLOWED = simple_hard_issue(
    :HIERA_INTERPOLATION_METHOD_SYNTAX_NOT_ALLOWED,
    'Interpolation using method syntax is not allowed in this context'
  )

  SERIALIZATION_ENDLESS_RECURSION = simple_hard_issue(
    :SERIALIZATION_ENDLESS_RECURSION,
    'Endless recursion detected when attempting to serialize value of class %{type_name}'
  )

  SERIALIZATION_DEFAULT_CONVERTED_TO_STRING = simple_issue(
    :SERIALIZATION_DEFAULT_CONVERTED_TO_STRING,
    "%{path} contains the special value default. It will be converted to the String 'default'"
  )

  SERIALIZATION_UNKNOWN_CONVERTED_TO_STRING = simple_issue(
    :SERIALIZATION_UNKNOWN_CONVERTED_TO_STRING,
    "%{path} contains %{klass} value. It will be converted to the String '%{value}'"
  )

  SERIALIZATION_UNKNOWN_KEY_CONVERTED_TO_STRING = simple_issue(
    :SERIALIZATION_UNKNOWN_KEY_CONVERTED_TO_STRING,
    "%{path} contains a hash with %{klass} key. It will be converted to the String '%{value}'"
  )

  FEATURE_NOT_SUPPORTED_WHEN_SCRIPTING = simple_issue(
    :NOT_SUPPORTED_WHEN_SCRIPTING,
    "The feature '%{feature}' is only available when compiling a catalog"
  )

  CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING = simple_issue(
    :CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING,
    "The catalog operation '%{operation}' is only available when compiling a catalog"
  )

  TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING = simple_issue(
    :TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
    "The task operation '%{operation}' is not available when compiling a catalog"
  )

  TASK_MISSING_BOLT = simple_issue(:TASK_MISSING_BOLT, "The 'bolt' library is required to %{action}")

  UNKNOWN_TASK = simple_issue(:UNKNOWN_TASK, 'Task not found: %{type_name}')

  LOADER_FAILURE = simple_issue(:LOADER_FAILURE, 'Failed to load: %{type_name}')

  DEPRECATED_APP_ORCHESTRATION = dynamic_issue :DEPRECATED_APP_ORCHESTRATION do |data|
    _("Use of the application-orchestration %{expr} is deprecated. See https://puppet.com/docs/puppet/5.5/deprecated_language.html" % { expr: data[:label].label(data[:klass]) })
  end

end
end
