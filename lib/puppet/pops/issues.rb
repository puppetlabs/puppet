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
      # Evaluate the message block in the msg data's binding
      msgdata.format(hash, &message_block)
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
    #
    def label
      raise "Label provider key :label must be set to produce the text of the message!" unless @data[:label]
      @data[:label]
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
  # @param *args [Symbol] required arguments that must be passed when formatting the message, may be empty
  # @param &block [Proc] a block producing the message string, evaluated in a MessageData scope. The produced string
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
    "#{label.a_an_uc(semantic)} may not have a name contain a hyphen. The name '#{name}' is not legal"
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

  # Assignment cannot be made to numeric match result variables
  ILLEGAL_NUMERIC_ASSIGNMENT = issue :ILLEGAL_NUMERIC_ASSIGNMENT, :varname do
    "Illegal attempt to assign to the numeric match result variable '$#{varname}'. Numeric variables are not assignable"
  end

  # parameters cannot have numeric names, clashes with match result variables
  ILLEGAL_NUMERIC_PARAMETER = issue :ILLEGAL_NUMERIC_PARAMETER, :name do
    "The numeric parameter name '$#{varname}' cannot be used (clashes with numeric match result variables)"
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
  # This is currently not supported, but may be in future versions
  #
  UNSUPPORTED_RANGE = issue :UNSUPPORTED_RANGE, :count do
    "Attempt to use unsupported range in #{label.a_an(semantic)}, #{count} values given for max 1"
  end

  DEPRECATED_NAME_AS_TYPE = issue :DEPRECATED_NAME_AS_TYPE, :name do
    "Resource references should now be capitalized. The given '#{name}' does not have the correct form"
  end
end
