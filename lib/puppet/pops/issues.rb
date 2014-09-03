# Defines classes to deal with issues, and message formatting and defines constants with Issues.
# @api public
#
module Puppet::Pops::Issues
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
        Puppet::Pops::Issues::MessageData
        raise RuntimeError, "Error while reporting issue: #{issue_code}. #{e.message}", caller
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
      instance_eval &block
    end

    # Returns the label provider given as a key in the hash passed to #format.
    # If given an argument, calls #label on the label provider (caller would otherwise have to
    # call label.label(it)
    #
    def label(it = nil)
      raise "Label provider key :label must be set to produce the text of the message!" unless @data[:label]
      it.nil? ? @data[:label] : @data[:label].label(it)
    end

    # Returns the label provider given as a key in the hash passed to #format.
    #
    def semantic
      raise "Label provider key :semantic must be set to produce the text of the message!" unless @data[:semantic]
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
  def self.issue (issue_code, *args, &block)
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
    "#{label.a_an_uc(semantic)} may not have a name containing a hyphen. The name '#{name}' is not legal"
  end

  # When a variable name contains a hyphen and these are illegal.
  # It is possible to control if a hyphen is legal in a name or not using the setting TODO
  # @todo describe the setting
  # @api public
  # @todo configuration if this is error or warning
  #
  VAR_WITH_HYPHEN = issue :VAR_WITH_HYPHEN, :name do
    "A variable name may not contain a hyphen. The name '#{name}' is not legal"
  end

  # A class, definition, or node may only appear at top level or inside other classes
  # @todo Is this really true for nodes? Can they be inside classes? Isn't that too late?
  # @api public
  #
  NOT_TOP_LEVEL = hard_issue :NOT_TOP_LEVEL do
    "Classes, definitions, and nodes may only appear at toplevel or inside other classes"
  end

  CROSS_SCOPE_ASSIGNMENT = hard_issue :CROSS_SCOPE_ASSIGNMENT, :name do
    "Illegal attempt to assign to '#{name}'. Cannot assign to variables in other namespaces"
  end

  # Assignment can only be made to certain types of left hand expressions such as variables.
  ILLEGAL_ASSIGNMENT = hard_issue :ILLEGAL_ASSIGNMENT do
    "Illegal attempt to assign to '#{label.a_an(semantic)}'. Not an assignable reference"
  end

  # Variables are immutable, cannot reassign in the same assignment scope
  ILLEGAL_REASSIGNMENT = hard_issue :ILLEGAL_REASSIGNMENT, :name do
    "Cannot reassign variable #{name}"
  end

  ILLEGAL_RESERVED_ASSIGNMENT = hard_issue :ILLEGAL_RESERVED_ASSIGNMENT, :name do
    "Attempt to assign to a reserved variable name: '#{name}'"
  end

  # Assignment cannot be made to numeric match result variables
  ILLEGAL_NUMERIC_ASSIGNMENT = issue :ILLEGAL_NUMERIC_ASSIGNMENT, :varname do
    "Illegal attempt to assign to the numeric match result variable '$#{varname}'. Numeric variables are not assignable"
  end

  # parameters cannot have numeric names, clashes with match result variables
  ILLEGAL_NUMERIC_PARAMETER = issue :ILLEGAL_NUMERIC_PARAMETER, :name do
    "The numeric parameter name '$#{name}' cannot be used (clashes with numeric match result variables)"
  end

  # In certain versions of Puppet it may be allowed to assign to a not already assigned key
  # in an array or a hash. This is an optional validation that may be turned on to prevent accidental
  # mutation.
  #
  ILLEGAL_INDEXED_ASSIGNMENT = issue :ILLEGAL_INDEXED_ASSIGNMENT do
    "Illegal attempt to assign via [index/key]. Not an assignable reference"
  end

  # When indexed assignment ($x[]=) is allowed, the leftmost expression must be
  # a variable expression.
  #
  ILLEGAL_ASSIGNMENT_VIA_INDEX = hard_issue :ILLEGAL_ASSIGNMENT_VIA_INDEX do
    "Illegal attempt to assign to #{label.a_an(semantic)} via [index/key]. Not an assignable reference"
  end

  APPENDS_DELETES_NO_LONGER_SUPPORTED = hard_issue :APPENDS_DELETES_NO_LONGER_SUPPORTED, :operator do
    "The operator '#{operator}' is no longer supported. See http://links.puppetlabs.com/remove-plus-equals"
  end

  # For unsupported operators (e.g. += and -= in puppet 4).
  #
  UNSUPPORTED_OPERATOR = hard_issue :UNSUPPORTED_OPERATOR, :operator do
    "The operator '#{operator}' is not supported."
  end

  # For operators that are not supported in specific contexts (e.g. '* =>' in
  # resource defaults)
  #
  UNSUPPORTED_OPERATOR_IN_CONTEXT = hard_issue :UNSUPPORTED_OPERATOR_IN_CONTEXT, :operator do
    "The operator '#{operator}' in #{label.a_an(semantic)} is not supported."
  end

  # For non applicable operators (e.g. << on Hash).
  #
  OPERATOR_NOT_APPLICABLE = hard_issue :OPERATOR_NOT_APPLICABLE, :operator, :left_value do
    "Operator '#{operator}' is not applicable to #{label.a_an(left_value)}."
  end

  COMPARISON_NOT_POSSIBLE = hard_issue :COMPARISON_NOT_POSSIBLE, :operator, :left_value, :right_value, :detail do
    "Comparison of: #{label(left_value)} #{operator} #{label(right_value)}, is not possible. Caused by '#{detail}'."
  end

  MATCH_NOT_REGEXP = hard_issue :MATCH_NOT_REGEXP, :detail do
    "Can not convert right match operand to a regular expression. Caused by '#{detail}'."
  end

  MATCH_NOT_STRING = hard_issue :MATCH_NOT_STRING, :left_value do
    "Left match operand must result in a String value. Got #{label.a_an(left_value)}."
  end

  # Some expressions/statements may not produce a value (known as right-value, or rvalue).
  # This may vary between puppet versions.
  #
  NOT_RVALUE = issue :NOT_RVALUE do
    "Invalid use of expression. #{label.a_an_uc(semantic)} does not produce a value"
  end

  # Appending to attributes is only allowed in certain types of resource expressions.
  #
  ILLEGAL_ATTRIBUTE_APPEND = hard_issue :ILLEGAL_ATTRIBUTE_APPEND, :name, :parent do
    "Illegal +> operation on attribute #{name}. This operator can not be used in #{label.a_an(parent)}"
  end

  ILLEGAL_NAME = hard_issue :ILLEGAL_NAME, :name do
    "Illegal name. The given name #{name} does not conform to the naming rule /^((::)?[a-z_]\w*)(::[a-z]\w*)*$/"
  end

  ILLEGAL_VAR_NAME = hard_issue :ILLEGAL_VAR_NAME, :name do
    "Illegal variable name, The given name '#{name}' does not conform to the naming rule /^((::)?[a-z]\w*)*((::)?[a-z_]\w*)$/"
  end

  ILLEGAL_NUMERIC_VAR_NAME = hard_issue :ILLEGAL_NUMERIC_VAR_NAME, :name do
    "Illegal numeric variable name, The given name '#{name}' must be a decimal value if it starts with a digit 0-9"
  end

  # In case a model is constructed programmatically, it must create valid type references.
  #
  ILLEGAL_CLASSREF = hard_issue :ILLEGAL_CLASSREF, :name do
    "Illegal type reference. The given name '#{name}' does not conform to the naming rule"
  end

  # This is a runtime issue - storeconfigs must be on in order to collect exported. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS = issue :RT_NO_STORECONFIGS do
    "You cannot collect exported resources without storeconfigs being set; the collection will be ignored"
  end

  # This is a runtime issue - storeconfigs must be on in order to export a resource. This issue should be
  # set to :ignore when just checking syntax.
  # @todo should be a :warning by default
  #
  RT_NO_STORECONFIGS_EXPORT = issue :RT_NO_STORECONFIGS_EXPORT do
    "You cannot collect exported resources without storeconfigs being set; the export is ignored"
  end

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_CHARS = hard_issue :ILLEGAL_HOSTNAME_CHARS, :hostname do
    "The hostname '#{hostname}' contains illegal characters (only letters, digits, '_', '-', and '.' are allowed)"
  end

  # A hostname may only contain letters, digits, '_', '-', and '.'.
  #
  ILLEGAL_HOSTNAME_INTERPOLATION = hard_issue :ILLEGAL_HOSTNAME_INTERPOLATION do
    "An interpolated expression is not allowed in a hostname of a node"
  end

  # Issues when an expression is used where it is not legal.
  # E.g. an arithmetic expression where a hostname is expected.
  #
  ILLEGAL_EXPRESSION = hard_issue :ILLEGAL_EXPRESSION, :feature, :container do
    "Illegal expression. #{label.a_an_uc(semantic)} is unacceptable as #{feature} in #{label.a_an(container)}"
  end

  # Issues when a variable is not a NAME
  #
  ILLEGAL_VARIABLE_EXPRESSION = hard_issue :ILLEGAL_VARIABLE_EXPRESSION do
    "Illegal variable expression. #{label.a_an_uc(semantic)} did not produce a variable name (String or Numeric)."
  end

  # Issues when an expression is used illegaly in a query.
  # query only supports == and !=, and not <, > etc.
  #
  ILLEGAL_QUERY_EXPRESSION = hard_issue :ILLEGAL_QUERY_EXPRESSION do
    "Illegal query expression. #{label.a_an_uc(semantic)} cannot be used in a query"
  end

  # If an attempt is made to make a resource default virtual or exported.
  #
  NOT_VIRTUALIZEABLE = hard_issue :NOT_VIRTUALIZEABLE do
    "Resource Defaults are not virtualizable"
  end

  # When an attempt is made to use multiple keys (to produce a range in Ruby - e.g. $arr[2,-1]).
  # This is not supported in 3x, but it allowed in 4x.
  #
  UNSUPPORTED_RANGE = issue :UNSUPPORTED_RANGE, :count do
    "Attempt to use unsupported range in #{label.a_an(semantic)}, #{count} values given for max 1"
  end

  ILLEGAL_RELATIONSHIP_OPERAND_TYPE = issue :ILLEGAL_RELATIONSHIP_OPERAND_TYPE, :operand do
    "Illegal relationship operand, can not form a relationship with #{label.a_an(operand)}. A Catalog type is required."
  end

  NOT_CATALOG_TYPE = issue :NOT_CATALOG_TYPE, :type do
    "Illegal relationship operand, can not form a relationship with something of type #{type}. A Catalog type is required."
  end

  BAD_STRING_SLICE_ARITY = issue :BAD_STRING_SLICE_ARITY, :actual do
    "String supports [] with one or two arguments. Got #{actual}"
  end

  BAD_STRING_SLICE_TYPE = issue :BAD_STRING_SLICE_TYPE, :actual do
    "String-Type [] requires all arguments to be integers (or default). Got #{actual}"
  end

  BAD_ARRAY_SLICE_ARITY = issue :BAD_ARRAY_SLICE_ARITY, :actual do
    "Array supports [] with one or two arguments. Got #{actual}"
  end

  BAD_HASH_SLICE_ARITY = issue :BAD_HASH_SLICE_ARITY, :actual do
    "Hash supports [] with one or more arguments. Got #{actual}"
  end

  BAD_INTEGER_SLICE_ARITY = issue :BAD_INTEGER_SLICE_ARITY, :actual do
    "Integer-Type supports [] with one or two arguments (from, to). Got #{actual}"
  end

  BAD_INTEGER_SLICE_TYPE = issue :BAD_INTEGER_SLICE_TYPE, :actual do
    "Integer-Type [] requires all arguments to be integers (or default). Got #{actual}"
  end

  BAD_COLLECTION_SLICE_TYPE = issue :BAD_COLLECTION_SLICE_TYPE, :actual do
    "A Type's size constraint arguments must be a single Integer type, or 1-2 integers (or default). Got #{label.a_an(actual)}"
  end

  BAD_FLOAT_SLICE_ARITY = issue :BAD_INTEGER_SLICE_ARITY, :actual do
    "Float-Type supports [] with one or two arguments (from, to). Got #{actual}"
  end

  BAD_FLOAT_SLICE_TYPE = issue :BAD_INTEGER_SLICE_TYPE, :actual do
    "Float-Type [] requires all arguments to be floats, or integers (or default). Got #{actual}"
  end

  BAD_SLICE_KEY_TYPE = issue :BAD_SLICE_KEY_TYPE, :left_value, :expected_classes, :actual do
    expected_text = if expected_classes.size > 1
      "one of #{expected_classes.join(', ')} are"
    else
      "#{expected_classes[0]} is"
    end
    "#{label.a_an_uc(left_value)}[] cannot use #{actual} where #{expected_text} expected"
  end

  BAD_TYPE_SLICE_TYPE = issue :BAD_TYPE_SLICE_TYPE, :base_type, :actual do
    "#{base_type}[] arguments must be types. Got #{actual}"
  end

  BAD_TYPE_SLICE_ARITY = issue :BAD_TYPE_SLICE_ARITY, :base_type, :min, :max, :actual do
    base_type_label = base_type.is_a?(String) ? base_type : label.a_an_uc(base_type)
    if max == -1 || max == 1.0 / 0.0 # Infinity
      "#{base_type_label}[] accepts #{min} or more arguments. Got #{actual}"
    elsif max && max != min
      "#{base_type_label}[] accepts #{min} to #{max} arguments. Got #{actual}"
    else
      "#{base_type_label}[] accepts #{min} #{label.plural_s(min, 'argument')}. Got #{actual}"
    end
  end

  BAD_TYPE_SPECIALIZATION = hard_issue :BAD_TYPE_SPECIALIZATION, :type, :message do
    "Error creating type specialization of #{label.a_an(type)}, #{message}"
  end

  ILLEGAL_TYPE_SPECIALIZATION = issue :ILLEGAL_TYPE_SPECIALIZATION, :kind do
    "Cannot specialize an already specialized #{kind} type"
  end

  ILLEGAL_RESOURCE_SPECIALIZATION = issue :ILLEGAL_RESOURCE_SPECIALIZATION, :actual do
    "First argument to Resource[] must be a resource type or a String. Got #{actual}."
  end

  EMPTY_RESOURCE_SPECIALIZATION = issue :EMPTY_RESOURCE_SPECIALIZATION do
    "Arguments to Resource[] are all empty/undefined"
  end

  ILLEGAL_HOSTCLASS_NAME = hard_issue :ILLEGAL_HOSTCLASS_NAME, :name do
    "Illegal Class name in class reference. #{label.a_an_uc(name)} cannot be used where a String is expected"
  end

  ILLEGAL_DEFINITION_NAME = hard_issue :ILLEGAL_DEFINTION_NAME, :name do
    "Unacceptable name. The name '#{name}' is unacceptable as the name of #{label.a_an(semantic)}"
  end

  CAPTURES_REST_NOT_LAST = hard_issue :CAPTURES_REST_NOT_LAST, :param_name do
    "Parameter $#{param_name} is not last, and has 'captures rest'"
  end

  CAPTURES_REST_NOT_SUPPORTED = hard_issue :CAPTURES_REST_NOT_SUPPORTED, :container, :param_name do
    "Parameter $#{param_name} has 'captures rest' - not supported in #{label.a_an(container)}"
  end

  REQUIRED_PARAMETER_AFTER_OPTIONAL = hard_issue :REQUIRED_PARAMETER_AFTER_OPTIONAL, :param_name do
    "Parameter $#{param_name} is required but appears after optional parameters"
  end

  MISSING_REQUIRED_PARAMETER = hard_issue :MISSING_REQUIRED_PARAMETER, :param_name do
    "Parameter $#{param_name} is required but no value was given"
  end

  NOT_NUMERIC = issue :NOT_NUMERIC, :value do
    "The value '#{value}' cannot be converted to Numeric."
  end

  UNKNOWN_FUNCTION = issue :UNKNOWN_FUNCTION, :name do
    "Unknown function: '#{name}'."
  end

  UNKNOWN_VARIABLE = issue :UNKNOWN_VARIABLE, :name do
    "Unknown variable: '#{name}'."
  end

  RUNTIME_ERROR = issue :RUNTIME_ERROR, :detail do
    "Error while evaluating #{label.a_an(semantic)}, #{detail}"
  end

  UNKNOWN_RESOURCE_TYPE = issue :UNKNOWN_RESOURCE_TYPE, :type_name do
    "Resource type not found: #{type_name.capitalize}"
  end

  ILLEGAL_RESOURCE_TYPE = hard_issue :ILLEGAL_RESOURCE_TYPE, :actual do
    "Illegal Resource Type expression, expected result to be a type name, or untitled Resource, got #{actual}"
  end

  DUPLICATE_TITLE = issue :DUPLICATE_TITLE, :title  do
    "The title '#{title}' has already been used in this resource expression"
  end

  DUPLICATE_ATTRIBUTE = issue :DUPLICATE_ATTRIBUE, :attribute  do
    "The attribute '#{attribute}' has already been set in this resource body"
  end

  MISSING_TITLE = hard_issue :MISSING_TITLE do
    "Missing title. The title expression resulted in undef"
  end

  MISSING_TITLE_AT = hard_issue :MISSING_TITLE_AT, :index do
    "Missing title at index #{index}. The title expression resulted in an undef title"
  end

  ILLEGAL_TITLE_TYPE_AT = hard_issue :ILLEGAL_TITLE_TYPE_AT, :index, :actual do
    "Illegal title type at index #{index}. Expected String, got #{actual}"
  end

  EMPTY_STRING_TITLE_AT = hard_issue :EMPTY_STRING_TITLE_AT, :index do
    "Empty string title at #{index}. Title strings must have a length greater than zero."
  end

  UNKNOWN_RESOURCE = issue :UNKNOWN_RESOURCE, :type_name, :title do
    "Resource not found: #{type_name.capitalize}['#{title}']"
  end

  UNKNOWN_RESOURCE_PARAMETER = issue :UNKNOWN_RESOURCE_PARAMETER, :type_name, :title, :param_name do
    "The resource #{type_name.capitalize}['#{title}'] does not have a parameter called '#{param_name}'"
  end

  DIV_BY_ZERO = hard_issue :DIV_BY_ZERO do
    "Division by 0"
  end

  RESULT_IS_INFINITY = hard_issue :RESULT_IS_INFINITY, :operator do
    "The result of the #{operator} expression is Infinity"
  end

  # TODO_HEREDOC
  EMPTY_HEREDOC_SYNTAX_SEGMENT = issue :EMPTY_HEREDOC_SYNTAX_SEGMENT, :syntax do
    "Heredoc syntax specification has empty segment between '+' : '#{syntax}'"
  end

  ILLEGAL_EPP_PARAMETERS = issue :ILLEGAL_EPP_PARAMETERS do
    "Ambiguous EPP parameter expression. Probably missing '<%-' before parameters to remove leading whitespace"
  end

  DISCONTINUED_IMPORT = hard_issue :DISCONTINUED_IMPORT do
    "Use of 'import' has been discontinued in favor of a manifest directory. See http://links.puppetlabs.com/puppet-import-deprecation"
  end

  IDEM_EXPRESSION_NOT_LAST = issue :IDEM_EXPRESSION_NOT_LAST do
    "This #{label.label(semantic)} is not productive. A non productive construct may only be placed last in a block/sequence"
  end

  IDEM_NOT_ALLOWED_LAST = hard_issue :IDEM_NOT_ALLOWED_LAST, :container do
    "This #{label.label(semantic)} is not productive. #{label.a_an_uc(container)} can not end with a non productive construct"
  end

  RESERVED_WORD = hard_issue :RESERVED_WORD, :word do
    "Use of reserved word: #{word}, must be quoted if intended to be a String value"
  end

  RESERVED_TYPE_NAME = hard_issue :RESERVED_TYPE_NAME, :name do
    "The name: '#{name}' is already defined by Puppet and can not be used as the name of #{label.a_an(semantic)}."
  end

  UNMATCHED_SELECTOR = hard_issue :UNMATCHED_SELECTOR, :param_value do
    "No matching entry for selector parameter with value '#{param_value}'"
  end

  ILLEGAL_NODE_INHERITANCE = issue :ILLEGAL_NODE_INHERITANCE do
    "Node inheritance is not supported in Puppet >= 4.0.0. See http://links.puppetlabs.com/puppet-node-inheritance-deprecation"
  end

  ILLEGAL_OVERRIDEN_TYPE = issue :ILLEGAL_OVERRIDEN_TYPE, :actual do
    "Resource Override can only operate on resources, got: #{label.label(actual)}"
  end

  RESERVED_PARAMETER = hard_issue :RESERVED_PARAMETER, :container, :param_name do
    "The parameter $#{param_name} redefines a built in parameter in #{label.the(container)}"
  end

  TYPE_MISMATCH = hard_issue :TYPE_MISMATCH, :expected, :actual do
    "Expected value of type #{expected}, got #{actual}"
  end

  MULTIPLE_ATTRIBUTES_UNFOLD = hard_issue :MULTIPLE_ATTRIBUTES_UNFOLD do
    "Unfolding of attributes from Hash can only be used once per resource body"
  end
end
