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
  NAME_WITH_HYPHEN = issue :NAME_WITH_HYPHEN, :name do
    _("%{issue} may not have a name containing a hyphen. The name '%{name}' is not legal") % { issue: label.a_an_uc(semantic), name: name }
  end

  # When a variable name contains a hyphen and these are illegal.
  # It is possible to control if a hyphen is legal in a name or not using the setting TODO
  # @todo describe the setting
  # @api public
  # @todo configuration if this is error or warning
  #
  VAR_WITH_HYPHEN = issue :VAR_WITH_HYPHEN, :name do
    _("A variable name may not contain a hyphen. The name '%{name}' is not legal") % { name: name }
  end

  # A class, definition, or node may only appear at top level or inside other classes
  # @todo Is this really true for nodes? Can they be inside classes? Isn't that too late?
  # @api public
  #
  NOT_TOP_LEVEL = hard_issue :NOT_TOP_LEVEL do
    _("Classes, definitions, and nodes may only appear at toplevel or inside other classes")
  end

  NOT_ABSOLUTE_TOP_LEVEL = hard_issue :NOT_ABSOLUTE_TOP_LEVEL do
    _("%{value} may only appear at toplevel") % { value: label.a_an_uc(semantic) }
  end

  CROSS_SCOPE_ASSIGNMENT = hard_issue :CROSS_SCOPE_ASSIGNMENT, :name do
    _("Illegal attempt to assign to '%{name}'. Cannot assign to variables in other namespaces") % { name: name }
  end

  # Assignment can only be made to certain types of left hand expressions such as variables.
  ILLEGAL_ASSIGNMENT = hard_issue :ILLEGAL_ASSIGNMENT do
    _("Illegal attempt to assign to '%{value}'. Not an assignable reference") % { value: label.a_an(semantic) }
  end

  # Variables are immutable, cannot reassign in the same assignment scope
  ILLEGAL_REASSIGNMENT = hard_issue :ILLEGAL_REASSIGNMENT, :name do
    if Validation::Checker4_0::RESERVED_PARAMETERS[name]
      _("Cannot reassign built in (or already assigned) variable '$%{var}'") % { var: name }
    else
      _("Cannot reassign variable '$%{var}'") % { var: name }
    end
  end

  # Variables facts and trusted
  ILLEGAL_RESERVED_ASSIGNMENT = hard_issue :ILLEGAL_RESERVED_ASSIGNMENT, :name do
    _("Attempt to assign to a reserved variable name: '$%{var}'") % { var: name }
  end

  # Assignment cannot be made to numeric match result variables
  ILLEGAL_NUMERIC_ASSIGNMENT = issue :ILLEGAL_NUMERIC_ASSIGNMENT, :varname do
    _("Illegal attempt to assign to the numeric match result variable '$%{var}'. Numeric variables are not assignable") % { var: varname }
  end

  # Assignment can only be made to certain types of left hand expressions such as variables.
  ILLEGAL_ASSIGNMENT_CONTEXT = hard_issue :ILLEGAL_ASSIGNMENT_CONTEXT do
    _("Assignment not allowed here")
  end

  # parameters cannot have numeric names, clashes with match result variables
  ILLEGAL_NUMERIC_PARAMETER = issue :ILLEGAL_NUMERIC_PARAMETER, :name do
    _("The numeric parameter name '$%{name}' cannot be used (clashes with numeric match result variables)") % { name: name }
  end

  # In certain versions of Puppet it may be allowed to assign to a not already assigned key
  # in an array or a hash. This is an optional validation that may be turned on to prevent accidental
  # mutation.
  #
  ILLEGAL_INDEXED_ASSIGNMENT = issue :ILLEGAL_INDEXED_ASSIGNMENT do
    _("Illegal attempt to assign via [index/key]. Not an assignable reference")
  end

  # When indexed assignment ($x[]=) is allowed, the leftmost expression must be
  # a variable expression.
  #
  ILLEGAL_ASSIGNMENT_VIA_INDEX = hard_issue :ILLEGAL_ASSIGNMENT_VIA_INDEX do
    _("Illegal attempt to assign to %{value} via [index/key]. Not an assignable reference") % { value: label.a_an(semantic) }
  end

  ILLEGAL_MULTI_ASSIGNMENT_SIZE = hard_issue :ILLEGAL_MULTI_ASSIGNMENT_SIZE, :expected, :actual do
    _("Mismatched number of assignable entries and values, expected %{expected}, got %{actual}") % { expected: expected, actual: actual }
  end

  MISSING_MULTI_ASSIGNMENT_KEY = hard_issue :MISSING_MULTI_ASSIGNMENT_KEY, :key do
    _("No value for required key '%{key}' in assignment to variables from hash") % { key: key }
  end

  MISSING_MULTI_ASSIGNMENT_VARIABLE = hard_issue :MISSING_MULTI_ASSIGNMENT_VARIABLE, :name do
    _("No value for required variable '$%{name}' in assignment to variables from class reference") % { name: name }
  end

  APPENDS_DELETES_NO_LONGER_SUPPORTED = hard_issue :APPENDS_DELETES_NO_LONGER_SUPPORTED, :operator do
    _("The operator '%{operator}' is no longer supported. See http://links.puppet.com/remove-plus-equals") % { operator: operator }
  end

  # For unsupported operators (e.g. += and -= in puppet 4).
  #
  UNSUPPORTED_OPERATOR = hard_issue :UNSUPPORTED_OPERATOR, :operator do
    _("The operator '%{operator}' is not supported.") % { operator: operator }
  end

  # For operators that are not supported in specific contexts (e.g. '* =>' in
  # resource defaults)
  #
  UNSUPPORTED_OPERATOR_IN_CONTEXT = hard_issue :UNSUPPORTED_OPERATOR_IN_CONTEXT, :operator do
    _("The operator '%{operator}' in %{value} is not supported.") % { operator: operator, value: label.a_an(semantic) }
  end

  # For non applicable operators (e.g. << on Hash).
  #
  OPERATOR_NOT_APPLICABLE = hard_issue :OPERATOR_NOT_APPLICABLE, :operator, :left_value do
    _("Operator '%{operator}' is not applicable to %{left}.") % { operator: operator, left: label.a_an(left_value) }
  end

  OPERATOR_NOT_APPLICABLE_WHEN = hard_issue :OPERATOR_NOT_APPLICABLE_WHEN, :operator, :left_value, :right_value do
    _("Operator '%{operator}' is not applicable to %{left} when right side is %{right}.") % { operator: operator, left: label.a_an(left_value), right: label.a_an(right_value) }
  end

  COMPARISON_NOT_POSSIBLE = hard_issue :COMPARISON_NOT_POSSIBLE, :operator, :left_value, :right_value, :detail do
    _("Comparison of: %{left} %{operator} %{right}, is not possible. Caused by '%{detail}'.") % { left: label(left_value), operator: operator, right: label(right_value), detail: detail }
  end

  MATCH_NOT_REGEXP = hard_issue :MATCH_NOT_REGEXP, :detail do
    _("Can not convert right match operand to a regular expression. Caused by '%{detail}'.") % { detail: detail }
  end

  MATCH_NOT_STRING = hard_issue :MATCH_NOT_STRING, :left_value do
    _("Left match operand must result in a String value. Got %{left}.") % { left: label.a_an(left_value) }
  end

  # Some expressions/statements may not produce a value (known as right-value, or rvalue).
  # This may vary between puppet versions.
  #
  NOT_RVALUE = issue :NOT_RVALUE do
    _("Invalid use of expression. %{value} does not produce a value") % { value: label.a_an_uc(semantic) }
  end

  # Appending to attributes is only allowed in certain types of resource expressions.
  #
  ILLEGAL_ATTRIBUTE_APPEND = hard_issue :ILLEGAL_ATTRIBUTE_APPEND, :name, :parent do
    _("Illegal +> operation on attribute %{attr}. This operator can not be used in %{expression}") % { attr: name, expression: label.a_an(parent) }
  end

  ILLEGAL_NAME = hard_issue :ILLEGAL_NAME, :name do
    _("Illegal name. The given name '%{name}' does not conform to the naming rule /^((::)?[a-z_]\w*)(::[a-z]\\w*)*$/") % { name: name }
  end

  ILLEGAL_SINGLE_TYPE_MAPPING = hard_issue :ILLEGAL_TYPE_MAPPING, :expression do
    _("Illegal type mapping. Expected a Type on the left side, got %{expression}") % { expression: label.a_an_uc(semantic) }
  end

  ILLEGAL_REGEXP_TYPE_MAPPING = hard_issue :ILLEGAL_TYPE_MAPPING, :expression do
    _("Illegal type mapping. Expected a Tuple[Regexp,String] on the left side, got %{expression}") % { expression: label.a_an_uc(semantic) }
  end

  ILLEGAL_PARAM_NAME = hard_issue :ILLEGAL_PARAM_NAME, :name do
    _("Illegal parameter name. The given name '%{name}' does not conform to the naming rule /^[a-z_]\\w*$/") % { name: name }
  end

  ILLEGAL_VAR_NAME = hard_issue :ILLEGAL_VAR_NAME, :name do
    _("Illegal variable name, The given name '%{name}' does not conform to the naming rule /^((::)?[a-z]\\w*)*((::)?[a-z_]\\w*)$/") % { name: name }
  end

  ILLEGAL_NUMERIC_VAR_NAME = hard_issue :ILLEGAL_NUMERIC_VAR_NAME, :name do
    _("Illegal numeric variable name, The given name '%{name}' must be a decimal value if it starts with a digit 0-9") % { name: name }
  end

  # In case a model is constructed programmatically, it must create valid type references.
  #
  ILLEGAL_CLASSREF = hard_issue :ILLEGAL_CLASSREF, :name do
    _("Illegal type reference. The given name '%{name}' does not conform to the naming rule") % { name: name }
  end

  # This is a runtime issue - storeconfigs must be on in order to collect exported. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS = issue :RT_NO_STORECONFIGS do
    _("You cannot collect exported resources without storeconfigs being set; the collection will be ignored")
  end

  # This is a runtime issue - storeconfigs must be on in order to export a resource. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS_EXPORT = issue :RT_NO_STORECONFIGS_EXPORT do
    _("You cannot collect exported resources without storeconfigs being set; the export is ignored")
  end

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_CHARS = hard_issue :ILLEGAL_HOSTNAME_CHARS, :hostname do
    _("The hostname '%{hostname}' contains illegal characters (only letters, digits, '_', '-', and '.' are allowed)") % { hostname: hostname }
  end

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_INTERPOLATION = hard_issue :ILLEGAL_HOSTNAME_INTERPOLATION do
    _("An interpolated expression is not allowed in a hostname of a node")
  end

  # Issues when an expression is used where it is not legal.
  # E.g. an arithmetic expression where a hostname is expected.
  #
  ILLEGAL_EXPRESSION = hard_issue :ILLEGAL_EXPRESSION, :feature, :container do
    _("Illegal expression. %{expression} is unacceptable as %{feature} in %{container}") % { expression: label.a_an_uc(semantic), feature: feature, container: label.a_an(container) }
  end

  # Issues when a variable is not a NAME
  #
  ILLEGAL_VARIABLE_EXPRESSION = hard_issue :ILLEGAL_VARIABLE_EXPRESSION do
    _("Illegal variable expression. %{expression} did not produce a variable name (String or Numeric).") % { expression: label.a_an_uc(semantic) }
  end

  # Issues when an expression is used illegally in a query.
  # query only supports == and !=, and not <, > etc.
  #
  ILLEGAL_QUERY_EXPRESSION = hard_issue :ILLEGAL_QUERY_EXPRESSION do
    _("Illegal query expression. %{expression} cannot be used in a query") % { expression: label.a_an_uc(semantic) }
  end

  # If an attempt is made to make a resource default virtual or exported.
  #
  NOT_VIRTUALIZEABLE = hard_issue :NOT_VIRTUALIZEABLE do
    _("Resource Defaults are not virtualizable")
  end

  CLASS_NOT_VIRTUALIZABLE = issue :CLASS_NOT_VIRTUALIZABLE do
    _("Classes are not virtualizable")
  end

  # When an attempt is made to use multiple keys (to produce a range in Ruby - e.g. $arr[2,-1]).
  # This is not supported in 3x, but it allowed in 4x.
  #
  UNSUPPORTED_RANGE = issue :UNSUPPORTED_RANGE, :count do
    _("Attempt to use unsupported range in %{expression}, %{count} values given for max 1") % { expression: label.a_an(semantic), count: count }
  end

  # Issues when expressions that are not implemented or activated in the current version are used.
  #
  UNSUPPORTED_EXPRESSION = issue :UNSUPPORTED_EXPRESSION do
    _("Expressions of type %{expression} are not supported in this version of Puppet") % { expression: label.a_an(semantic) }
  end

  ILLEGAL_RELATIONSHIP_OPERAND_TYPE = issue :ILLEGAL_RELATIONSHIP_OPERAND_TYPE, :operand do
    _("Illegal relationship operand, can not form a relationship with %{expression}. A Catalog type is required.") % { expression: label.a_an(operand) }
  end

  NOT_CATALOG_TYPE = issue :NOT_CATALOG_TYPE, :type do
    _("Illegal relationship operand, can not form a relationship with something of type %{expression_type}. A Catalog type is required.") % { expression_type: type }
  end

  BAD_STRING_SLICE_ARITY = issue :BAD_STRING_SLICE_ARITY, :actual do
    _("String supports [] with one or two arguments. Got %{actual}") % { actual: actual }
  end

  BAD_STRING_SLICE_TYPE = issue :BAD_STRING_SLICE_TYPE, :actual do
    _("String-Type [] requires all arguments to be integers (or default). Got %{actual}") % { actual: actual }
  end

  BAD_ARRAY_SLICE_ARITY = issue :BAD_ARRAY_SLICE_ARITY, :actual do
    _("Array supports [] with one or two arguments. Got %{actual}") % { actual: actual }
  end

  BAD_HASH_SLICE_ARITY = issue :BAD_HASH_SLICE_ARITY, :actual do
    _("Hash supports [] with one or more arguments. Got %{actual}") % { actual: actual }
  end

  BAD_INTEGER_SLICE_ARITY = issue :BAD_INTEGER_SLICE_ARITY, :actual do
    _("Integer-Type supports [] with one or two arguments (from, to). Got %{actual}") % { actual: actual }
  end

  BAD_INTEGER_SLICE_TYPE = issue :BAD_INTEGER_SLICE_TYPE, :actual do
    _("Integer-Type [] requires all arguments to be integers (or default). Got %{actual}") % { actual: actual }
  end

  BAD_COLLECTION_SLICE_TYPE = issue :BAD_COLLECTION_SLICE_TYPE, :actual do
    _("A Type's size constraint arguments must be a single Integer type, or 1-2 integers (or default). Got %{actual}") % { actual: label.a_an(actual) }
  end

  BAD_FLOAT_SLICE_ARITY = issue :BAD_INTEGER_SLICE_ARITY, :actual do
    _("Float-Type supports [] with one or two arguments (from, to). Got %{actual}") % { actual: actual }
  end

  BAD_FLOAT_SLICE_TYPE = issue :BAD_INTEGER_SLICE_TYPE, :actual do
    _("Float-Type [] requires all arguments to be floats, or integers (or default). Got %{actual}") % { actual: actual }
  end

  BAD_SLICE_KEY_TYPE = issue :BAD_SLICE_KEY_TYPE, :left_value, :expected_classes, :actual do
    expected_text = if expected_classes.size > 1
      _("one of %{expected} are") % { expected: expected_classes.join(', ') }
    else
      _("%{expected} is") % { expected: expected_classes[0] }
    end
    _("%{expression}[] cannot use %{actual} where %{expected_text} expected") % { expression: label.a_an_uc(left_value), actual: actual, expected_text: expected_text }
  end

  BAD_STRING_SLICE_KEY_TYPE = issue :BAD_STRING_SLICE_KEY_TYPE, :left_value, :actual_type do
    _("A substring operation does not accept %{label_article} %{actual_type} as a character index. Expected an Integer") % { label_article: label.article(actual_type), actual_type: actual_type }
  end

  BAD_NOT_UNDEF_SLICE_TYPE = issue :BAD_NOT_UNDEF_SLICE_TYPE, :base_type, :actual do
    _("%{expression}[] argument must be a Type or a String. Got %{actual}") % { expression: base_type, actual: actual }
  end

  BAD_TYPE_SLICE_TYPE = issue :BAD_TYPE_SLICE_TYPE, :base_type, :actual do
    _("%{base_type}[] arguments must be types. Got %{actual}") % { base_type: base_type, actual: actual }
  end

  BAD_TYPE_SLICE_ARITY = issue :BAD_TYPE_SLICE_ARITY, :base_type, :min, :max, :actual do
    base_type_label = base_type.is_a?(String) ? base_type : label.a_an_uc(base_type)
    if max == -1 || max == Float::INFINITY
      _("%{base_type_label}[] accepts %{min} or more arguments. Got %{actual}") % { base_type_label: base_type_label, min: min, actual: actual }
    elsif max && max != min
      _("%{base_type_label}[] accepts %{min} to %{max} arguments. Got %{actual}") % { base_type_label: base_type_label, min: min, max: max, actual: actual }
    else
      _("%{base_type_label}[] accepts %{min} %{label}. Got %{actual}") % { base_type_label: base_type_label, min: min, label: label.plural_s(min, _('argument')), actual: actual }
    end
  end

  BAD_TYPE_SPECIALIZATION = hard_issue :BAD_TYPE_SPECIALIZATION, :type, :message do
    _("Error creating type specialization of %{base_type}, %{message}") % { base_type: label.a_an(type), message: message }
  end

  ILLEGAL_TYPE_SPECIALIZATION = issue :ILLEGAL_TYPE_SPECIALIZATION, :kind do
    _("Cannot specialize an already specialized %{kind} type") % { kind: kind }
  end

  ILLEGAL_RESOURCE_SPECIALIZATION = issue :ILLEGAL_RESOURCE_SPECIALIZATION, :actual do
    _("First argument to Resource[] must be a resource type or a String. Got %{actual}.") % { actual: actual }
  end

  EMPTY_RESOURCE_SPECIALIZATION = issue :EMPTY_RESOURCE_SPECIALIZATION do
    _("Arguments to Resource[] are all empty/undefined")
  end

  ILLEGAL_HOSTCLASS_NAME = hard_issue :ILLEGAL_HOSTCLASS_NAME, :name do
    _("Illegal Class name in class reference. %{expression} cannot be used where a String is expected") % { expression: label.a_an_uc(name) }
  end

  ILLEGAL_DEFINITION_NAME = hard_issue :ILLEGAL_DEFINITION_NAME, :name do
    _("Unacceptable name. The name '%{name}' is unacceptable as the name of %{value}") % { name: name, value: label.a_an(semantic) }
  end

  CAPTURES_REST_NOT_LAST = hard_issue :CAPTURES_REST_NOT_LAST, :param_name do
    _("Parameter $%{param} is not last, and has 'captures rest'") % { param: param_name }
  end

  CAPTURES_REST_NOT_SUPPORTED = hard_issue :CAPTURES_REST_NOT_SUPPORTED, :container, :param_name do
    _("Parameter $%{param} has 'captures rest' - not supported in %{container}") % { param: param_name, container: label.a_an(container) }
  end

  REQUIRED_PARAMETER_AFTER_OPTIONAL = hard_issue :REQUIRED_PARAMETER_AFTER_OPTIONAL, :param_name do
    _("Parameter $%{param} is required but appears after optional parameters") % { param: param_name }
  end

  MISSING_REQUIRED_PARAMETER = hard_issue :MISSING_REQUIRED_PARAMETER, :param_name do
    _("Parameter $%{param} is required but no value was given") % { param: param_name }
  end

  NOT_NUMERIC = issue :NOT_NUMERIC, :value do
    _("The value '%{value}' cannot be converted to Numeric.") % { value: value }
  end

  NUMERIC_COERCION = issue :NUMERIC_COERCION, :before, :after do
    _("The string '%{before}' was automatically coerced to the numerical value %{after}") % { before: before, after: after }
  end

  UNKNOWN_FUNCTION = issue :UNKNOWN_FUNCTION, :name do
    _("Unknown function: '%{name}'.") % { name: name }
  end

  UNKNOWN_VARIABLE = issue :UNKNOWN_VARIABLE, :name do
    _("Unknown variable: '%{name}'.") % { name: name }
  end

  RUNTIME_ERROR = issue :RUNTIME_ERROR, :detail do
    _("Error while evaluating %{expression}, %{detail}") % { expression: label.a_an(semantic), detail: detail }
  end

  UNKNOWN_RESOURCE_TYPE = issue :UNKNOWN_RESOURCE_TYPE, :type_name do
    _("Resource type not found: %{res_type}") % { res_type: type_name }
  end

  ILLEGAL_RESOURCE_TYPE = hard_issue :ILLEGAL_RESOURCE_TYPE, :actual do
    _("Illegal Resource Type expression, expected result to be a type name, or untitled Resource, got %{actual}") % { actual: actual }
  end

  DUPLICATE_TITLE = issue :DUPLICATE_TITLE, :title  do
    _("The title '%{title}' has already been used in this resource expression") % { title: title }
  end

  DUPLICATE_ATTRIBUTE = issue :DUPLICATE_ATTRIBUE, :attribute  do
    _("The attribute '%{attribute}' has already been set") % { attribute: attribute }
  end

  MISSING_TITLE = hard_issue :MISSING_TITLE do
    _("Missing title. The title expression resulted in undef")
  end

  MISSING_TITLE_AT = hard_issue :MISSING_TITLE_AT, :index do
    _("Missing title at index %{index}. The title expression resulted in an undef title") % { index: index }
  end

  ILLEGAL_TITLE_TYPE_AT = hard_issue :ILLEGAL_TITLE_TYPE_AT, :index, :actual do
    _("Illegal title type at index %{index}. Expected String, got %{actual}") % { index: index, actual: actual }
  end

  EMPTY_STRING_TITLE_AT = hard_issue :EMPTY_STRING_TITLE_AT, :index do
    _("Empty string title at %{index}. Title strings must have a length greater than zero.") % { index: index }
  end

  UNKNOWN_RESOURCE = issue :UNKNOWN_RESOURCE, :type_name, :title do
    _("Resource not found: %{type_name}['%{title}']") % { type_name: type_name, title: title }
  end

  UNKNOWN_RESOURCE_PARAMETER = issue :UNKNOWN_RESOURCE_PARAMETER, :type_name, :title, :param_name do
    _("The resource %{type_name}['%{title}'] does not have a parameter called '%{param}'") % { type_name: type_name.capitalize, title: title, param: param_name }
  end

  DIV_BY_ZERO = hard_issue :DIV_BY_ZERO do
    _("Division by 0")
  end

  RESULT_IS_INFINITY = hard_issue :RESULT_IS_INFINITY, :operator do
    _("The result of the %{operator} expression is Infinity") % { operator: operator }
  end

  # TODO_HEREDOC
  EMPTY_HEREDOC_SYNTAX_SEGMENT = issue :EMPTY_HEREDOC_SYNTAX_SEGMENT, :syntax do
    _("Heredoc syntax specification has empty segment between '+' : '%{syntax}'") % { syntax: syntax }
  end

  ILLEGAL_EPP_PARAMETERS = issue :ILLEGAL_EPP_PARAMETERS do
    _("Ambiguous EPP parameter expression. Probably missing '<%-' before parameters to remove leading whitespace")
  end

  DISCONTINUED_IMPORT = hard_issue :DISCONTINUED_IMPORT do
    #TRANSLATORS "import" is a function name and should not be translated
    _("Use of 'import' has been discontinued in favor of a manifest directory. See http://links.puppet.com/puppet-import-deprecation")
  end

  IDEM_EXPRESSION_NOT_LAST = issue :IDEM_EXPRESSION_NOT_LAST do
    _("This %{expression} has no effect. A value was produced and then forgotten (one or more preceding expressions may have the wrong form)") % { expression: label.label(semantic) }
  end

  RESOURCE_WITHOUT_TITLE = issue :RESOURCE_WITHOUT_TITLE, :name do
    _("This expression is invalid. Did you try declaring a '%{name}' resource without a title?") % { name: name }
  end

  IDEM_NOT_ALLOWED_LAST = hard_issue :IDEM_NOT_ALLOWED_LAST, :container do
    _("This %{expression} has no effect. %{container} can not end with a value-producing expression without other effect") % { expression: label.label(semantic), container: label.a_an_uc(container) }
  end

  RESERVED_WORD = hard_issue :RESERVED_WORD, :word do
    _("Use of reserved word: %{word}, must be quoted if intended to be a String value") % { word: word }
  end

  FUTURE_RESERVED_WORD = issue :FUTURE_RESERVED_WORD, :word do
    _("Use of future reserved word: '%{word}'") % { word: word }
  end

  RESERVED_TYPE_NAME = hard_issue :RESERVED_TYPE_NAME, :name do
    _("The name: '%{name}' is already defined by Puppet and can not be used as the name of %{expression}.") % { name: name, expression: label.a_an(semantic) }
  end

  UNMATCHED_SELECTOR = hard_issue :UNMATCHED_SELECTOR, :param_value do
    _("No matching entry for selector parameter with value '%{param}'") % { param: param_value }
  end

  ILLEGAL_NODE_INHERITANCE = issue :ILLEGAL_NODE_INHERITANCE do
    _("Node inheritance is not supported in Puppet >= 4.0.0. See http://links.puppet.com/puppet-node-inheritance-deprecation")
  end

  ILLEGAL_OVERRIDDEN_TYPE = issue :ILLEGAL_OVERRIDDEN_TYPE, :actual do
    _("Resource Override can only operate on resources, got: %{actual}") % { actual: label.label(actual) }
  end

  DUPLICATE_PARAMETER = hard_issue :DUPLICATE_PARAMETER, :param_name do
    _("The parameter '%{param}' is declared more than once in the parameter list") % { param: param_name }
  end

  DUPLICATE_KEY = issue :DUPLICATE_KEY, :key do
    _("The key '%{key}' is declared more than once") % { key: key }
  end

  DUPLICATE_DEFAULT = hard_issue :DUPLICATE_DEFAULT, :container do
    _("This %{container} already has a 'default' entry - this is a duplicate") % { container: label.label(container) }
  end

  RESERVED_PARAMETER = hard_issue :RESERVED_PARAMETER, :container, :param_name do
    _("The parameter $%{param} redefines a built in parameter in %{container}") % { param: param_name, container: label.the(container) }
  end

  TYPE_MISMATCH = hard_issue :TYPE_MISMATCH, :expected, :actual do
    _("Expected value of type %{expected}, got %{actual}") % { expected: expected, actual: actual }
  end

  MULTIPLE_ATTRIBUTES_UNFOLD = hard_issue :MULTIPLE_ATTRIBUTES_UNFOLD do
    _("Unfolding of attributes from Hash can only be used once per resource body")
  end

  ILLEGAL_CATALOG_RELATED_EXPRESSION = hard_issue :ILLEGAL_CATALOG_RELATED_EXPRESSION do
    _("This %{expression} appears in a context where catalog related expressions are not allowed") % { expression: label.label(semantic) }
  end

  SYNTAX_ERROR = hard_issue :SYNTAX_ERROR, :where do
    _("Syntax error at %{location}") % { location: where }
  end

  ILLEGAL_CLASS_REFERENCE = hard_issue :ILLEGAL_CLASS_REFERENCE do
    _('Illegal class reference')
  end

  ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE = hard_issue :ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE do
    _('Illegal fully qualified class reference')
  end

  ILLEGAL_FULLY_QUALIFIED_NAME = hard_issue :ILLEGAL_FULLY_QUALIFIED_NAME do
    _('Illegal fully qualified name')
  end

  ILLEGAL_NAME_OR_BARE_WORD = hard_issue :ILLEGAL_NAME_OR_BARE_WORD do
    _('Illegal name or bare word')
  end

  ILLEGAL_NUMBER = hard_issue :ILLEGAL_NUMBER, :value do
    _("Illegal number '%{value}'") % { value: value }
  end

  ILLEGAL_UNICODE_ESCAPE = issue :ILLEGAL_UNICODE_ESCAPE do
    _("Unicode escape '\\u' was not followed by 4 hex digits or 1-6 hex digits in {} or was > 10ffff")
  end

  INVALID_HEX_NUMBER = hard_issue :INVALID_HEX_NUMBER, :value do
    _("Not a valid hex number %{value}") % { value: value }
  end

  INVALID_OCTAL_NUMBER = hard_issue :INVALID_OCTAL_NUMBER, :value do
    _("Not a valid octal number %{value}") % { value: value }
  end

  INVALID_DECIMAL_NUMBER = hard_issue :INVALID_DECIMAL_NUMBER, :value do
    _("Not a valid decimal number %{value}") % { value: value }
  end

  NO_INPUT_TO_LEXER = hard_issue :NO_INPUT_TO_LEXER do
    _("Internal Error: No string or file given to lexer to process.")
  end

  UNRECOGNIZED_ESCAPE = issue :UNRECOGNIZED_ESCAPE, :ch do
    _("Unrecognized escape sequence '\\%{ch}'") % { ch: ch }
  end

  UNCLOSED_QUOTE = hard_issue :UNCLOSED_QUOTE, :after, :followed_by do
    _("Unclosed quote after %{after} followed by '%{followed_by}'") % { after: after, followed_by: followed_by }
  end

  UNCLOSED_MLCOMMENT = hard_issue :UNCLOSED_MLCOMMENT do
    _('Unclosed multiline comment')
  end

  EPP_INTERNAL_ERROR = hard_issue :EPP_INTERNAL_ERROR, :error do
    _("Internal error: %{error}") % { error: error }
  end

  EPP_UNBALANCED_TAG = hard_issue :EPP_UNBALANCED_TAG do
    _('Unbalanced epp tag, reached <eof> without closing tag.')
  end

  EPP_UNBALANCED_COMMENT = hard_issue :EPP_UNBALANCED_COMMENT do
    _('Reaching end after opening <%# without seeing %>')
  end

  EPP_UNBALANCED_EXPRESSION = hard_issue :EPP_UNBALANCED_EXPRESSION do
    _('Unbalanced embedded expression - opening <% and reaching end of input')
  end

  HEREDOC_UNCLOSED_PARENTHESIS = hard_issue :HEREDOC_UNCLOSED_PARENTHESIS, :followed_by do
    _("Unclosed parenthesis after '@(' followed by '%{followed_by}'") % { followed_by: followed_by }
  end

  HEREDOC_WITHOUT_END_TAGGED_LINE = hard_issue :HEREDOC_WITHOUT_END_TAGGED_LINE do
    _('Heredoc without end-tagged line')
  end

  HEREDOC_INVALID_ESCAPE = hard_issue :HEREDOC_INVALID_ESCAPE, :actual do
    _("Invalid heredoc escape char. Only t, r, n, s,  u, L, $ allowed. Got '%{actual}'") % { actual: actual }
  end

  HEREDOC_INVALID_SYNTAX = hard_issue :HEREDOC_INVALID_SYNTAX do
    _('Invalid syntax in heredoc expected @(endtag[:syntax][/escapes])')
  end

  HEREDOC_WITHOUT_TEXT = hard_issue :HEREDOC_WITHOUT_TEXT do
    _('Heredoc without any following lines of text')
  end

  HEREDOC_EMPTY_ENDTAG = hard_issue :HEREDOC_EMPTY_ENDTAG do
    _('Heredoc with an empty endtag')
  end

  HEREDOC_MULTIPLE_AT_ESCAPES = hard_issue :HEREDOC_MULTIPLE_AT_ESCAPES, :escapes do
    _("An escape char for @() may only appear once. Got '%{escapes}'") % { escapes: escapes.join(', ') }
  end

  ILLEGAL_BOM = hard_issue :ILLEGAL_BOM, :format_name, :bytes do
    _("Illegal %{format} Byte Order mark at beginning of input: %{bom} - remove these from the puppet source") % { format: format_name, bom: bytes }
  end

  NO_SUCH_FILE_OR_DIRECTORY = hard_issue :NO_SUCH_FILE_OR_DIRECTORY, :file do
    _('No such file or directory: %{file}') % { file: file }
  end

  NOT_A_FILE = hard_issue :NOT_A_FILE, :file do
    _('%{file} is not a file') % { file: file }
  end

  NUMERIC_OVERFLOW = hard_issue :NUMERIC_OVERFLOW, :value do
    if value > 0
      _("%{expression} resulted in a value outside of Puppet Integer max range, got '%{value}'") % { expression: label.a_an_uc(semantic), value: ("%#+x" % value) }
    else
      _("%{expression} resulted in a value outside of Puppet Integer min range, got '%{value}'") % { expression: label.a_an_uc(semantic), value: ("%#+x" % value) }
    end
  end

  HIERA_UNSUPPORTED_VERSION = hard_issue :HIERA_UNSUPPORTED_VERSION, :version do
    _("This runtime does not support hiera.yaml version %{version}") % { version: version }
  end

  HIERA_VERSION_3_NOT_GLOBAL = hard_issue :HIERA_VERSION_3_NOT_GLOBAL, :where do
    _("hiera.yaml version 3 cannot be used in %{location}") % { location: label.a_an(where) }
  end

  HIERA_UNSUPPORTED_VERSION_IN_GLOBAL = hard_issue :HIERA_UNSUPPORTED_VERSION_IN_GLOBAL do
    _('hiera.yaml version 4 cannot be used in the global layer')
  end

  HIERA_UNDEFINED_VARIABLE = hard_issue :HIERA_UNDEFINED_VARIABLE, :name do
    _("Undefined variable '%{name}'") % { name: name }
  end

  HIERA_BACKEND_MULTIPLY_DEFINED = hard_issue :HIERA_BACKEND_MULTIPLY_DEFINED, :name, :first_line do
    msg = _("Backend '%{name}' is defined more than once.") % { name: name }
    fl = first_line
    if fl
      msg += ' ' + _("First defined at %{error_location}") % { error_location: Puppet::Util::Errors.error_location(nil, fl) }
    end
    msg
  end

  HIERA_NO_PROVIDER_FOR_BACKEND = hard_issue :HIERA_NO_PROVIDER_FOR_BACKEND, :name do
    _("No data provider is registered for backend '%{name}'") % { name: name }
  end

  HIERA_HIERARCHY_NAME_MULTIPLY_DEFINED = hard_issue :HIERA_HIERARCHY_NAME_MULTIPLY_DEFINED, :name, :first_line do
    msg = _("Hierarchy name '%{name}' defined more than once.") % { name: name }
    fl = first_line
    if fl
      msg += ' ' + _("First defined at %{error_location}") % { error_location: Puppet::Util::Errors.error_location(nil, fl) }
    end
    msg
  end

  HIERA_V3_BACKEND_NOT_GLOBAL = hard_issue :HIERA_V3_BACKEND_NOT_GLOBAL do
    _("'hiera3_backend' is only allowed in the global layer")
  end

  HIERA_DEFAULT_HIERARCHY_NOT_IN_MODULE = hard_issue :HIERA_DEFAULT_HIERARCHY_NOT_IN_MODULE do
    _("'default_hierarchy' is only allowed in the module layer")
  end

  HIERA_V3_BACKEND_REPLACED_BY_DATA_HASH = hard_issue :HIERA_V3_BACKEND_REPLACED_BY_DATA_HASH, :function_name do
    _("Use \"data_hash: %{function_name}_data\" instead of \"hiera3_backend: %{function_name}\"") % { function_name: function_name }
  end

  HIERA_MISSING_DATA_PROVIDER_FUNCTION = hard_issue :HIERA_MISSING_DATA_PROVIDER_FUNCTION, :name do
    _("One of %{keys} must be defined in hierarchy '%{name}'") % { keys: label.combine_strings(Lookup::HieraConfig::FUNCTION_KEYS), name: name }
  end

  HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS = hard_issue :HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS, :name do
    _("Only one of %{keys} can be defined in hierarchy '%{name}'") % { keys: label.combine_strings(Lookup::HieraConfig::FUNCTION_KEYS), name: name }
  end

  HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS_IN_DEFAULT = hard_issue :HIERA_MULTIPLE_DATA_PROVIDER_FUNCTIONS_IN_DEFAULT do
    _("Only one of %{keys} can be defined in defaults") % { keys: label.combine_strings(Lookup::HieraConfig::FUNCTION_KEYS) }
  end

  HIERA_MULTIPLE_LOCATION_SPECS = hard_issue :HIERA_MULTIPLE_LOCATION_SPECS, :name do
    _("Only one of %{keys} can be defined in hierarchy '%{name}'") % { keys: label.combine_strings(Lookup::HieraConfig::LOCATION_KEYS), name: name }
  end

  HIERA_OPTION_RESERVED_BY_PUPPET = hard_issue :HIERA_OPTION_RESERVED_BY_PUPPET, :key, :name do
    _("Option key '%{key}' used in hierarchy '%{name}' is reserved by Puppet") % { key: key, name: name }
  end

  HIERA_DEFAULT_OPTION_RESERVED_BY_PUPPET = hard_issue :HIERA_DEFAULT_OPTION_RESERVED_BY_PUPPET, :key do
    _("Option key '%{key}' used in defaults is reserved by Puppet") % { key: key }
  end

  HIERA_DATA_PROVIDER_FUNCTION_NOT_FOUND = hard_issue :HIERA_DATA_PROVIDER_FUNCTION_NOT_FOUND, :function_type, :function_name do
    _("Unable to find '%{function_type}' function named '%{function_name}'") % { function_type: function_type, function_name: function_name }
  end

  HIERA_INTERPOLATION_ALIAS_NOT_ENTIRE_STRING = hard_issue :HIERA_INTERPOLATION_ALIAS_NOT_ENTIRE_STRING do
    _("'alias' interpolation is only permitted if the expression is equal to the entire string")
  end

  HIERA_INTERPOLATION_UNKNOWN_INTERPOLATION_METHOD = hard_issue :HIERA_INTERPOLATION_UNKNOWN_INTERPOLATION_METHOD, :name do
    _("Unknown interpolation method '%{name}'") % { name: name }
  end

  HIERA_INTERPOLATION_METHOD_SYNTAX_NOT_ALLOWED = hard_issue :HIERA_INTERPOLATION_METHOD_SYNTAX_NOT_ALLOWED do
    _('Interpolation using method syntax is not allowed in this context')
  end

  SERIALIZATION_ENDLESS_RECURSION = hard_issue :SERIALIZATION_ENDLESS_RECURSION, :type_name do
    _('Endless recursion detected when attempting to serialize value of class %{type_name}') % { :type_name => type_name }
  end

  SERIALIZATION_DEFAULT_CONVERTED_TO_STRING = issue :SERIALIZATION_DEFAULT_CONVERTED_TO_STRING, :path, :klass, :value do
    _("%{path} contains the special value default. It will be converted to the String 'default'") % { path: path }
  end

  SERIALIZATION_UNKNOWN_CONVERTED_TO_STRING = issue :SERIALIZATION_UNKNOWN_CONVERTED_TO_STRING, :path, :klass, :value do
    _("%{path} contains %{klass} value. It will be converted to the String '%{value}'") % { path: path, klass: label.a_an(klass), value: value }
  end

  SERIALIZATION_UNKNOWN_KEY_CONVERTED_TO_STRING = issue :SERIALIZATION_UNKNOWN_KEY_CONVERTED_TO_STRING, :path, :klass, :value do
    _("%{path} contains a hash with %{klass} key. It will be converted to the String '%{value}'") % { path: path, klass: label.a_an(klass), value: value }
  end

  FEATURE_NOT_SUPPORTED_WHEN_SCRIPTING = issue :NOT_SUPPORTED_WHEN_SCRIPTING, :feature do
    _("The feature '%{feature}' is only available when compiling a catalog") % { feature: feature }
  end

  CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING = issue :CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING, :operation do
    _("The catalog operation '%{operation}' is only available when compiling a catalog") % { operation: operation }
  end

  TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING = issue :TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, :operation do
    _("The task operation '%{operation}' is not available when compiling a catalog") % { operation: operation }
  end

  TASK_MISSING_BOLT = issue :TASK_MISSING_BOLT, :action do
    _("The 'bolt' library is required to %{action}") % { action: action }
  end

  UNKNOWN_TASK = issue :UNKNOWN_TASK, :type_name do
    _('Task not found: %{type_name}') % { type_name: type_name }
  end

  LOADER_FAILURE = issue :LOADER_FAILURE, :type do
    _('Failed to load: %{type_name}') % { type: type }
  end
end
end
