module Puppet::Pops
# @api public
module Binder::BinderIssues

  # NOTE: The methods #issue and #hard_issue are done in a somewhat funny way
  # since the Issues is a module with these methods defined on the module-class
  # This makes it hard to inherit them in this module. (Likewise if Issues was a class, and they
  # need to be defined for the class, and such methods are also not inherited, it becomes more
  # difficult to reuse these. It did not seem as a good idea to refactor Issues at this point
  # in time - they should both probably be refactored once bindings support is finished.
  # Meanwhile, they delegate to Issues.


  # (see Issues#issue)
  def self.issue (issue_code, *args, &block)
    Issues.issue(issue_code, *args, &block)
  end

  # (see Issues#hard_issue)
  def self.hard_issue(issue_code, *args, &block)
    Issues.hard_issue(issue_code, *args, &block)
  end

  # Producer issues (binding identified using :binding argument)

  # @api public
  MISSING_NAME = issue :MISSING_NAME, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no name"
  end

  # @api public
  MISSING_KEY = issue :MISSING_KEY, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no key"
  end

  # @api public
  MISSING_VALUE = issue :MISSING_VALUE, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no value"
  end

  # @api public
  MISSING_EXPRESSION = issue :MISSING_EXPRESSION, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no expression"
  end

  # @api public
  MISSING_CLASS_NAME = issue :MISSING_CLASS_NAME, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no class name"
  end

  # @api public
  CACHED_PRODUCER_MISSING_PRODUCER = issue :PRODUCER_MISSING_PRODUCER, :binding do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has no producer"
  end

  # @api public
  INCOMPATIBLE_TYPE = issue :INCOMPATIBLE_TYPE, :binding, :expected_type, :actual_type do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} has an incompatible type: expected #{label.a_an(expected_type)}, but got #{label.a_an(actual_type)}."
  end

  # @api public
  MULTIBIND_INCOMPATIBLE_TYPE = issue :MULTIBIND_INCOMPATIBLE_TYPE, :binding, :actual_type do
    "#{label.a_an_uc(binding)} with #{label.a_an(semantic)} cannot bind #{label.a_an(actual_type)} value"
  end

  # @api public
  MODEL_OBJECT_IS_UNBOUND = issue :MODEL_OBJECT_IS_UNBOUND do
    "#{label.a_an_uc(semantic)} is not contained in a binding"
  end

  # Binding issues (binding identified using semantic)

  # @api public
  MISSING_PRODUCER = issue :MISSING_PRODUCER do
    "#{label.a_an_uc(semantic)} has no producer"
  end

  # @api public
  MISSING_TYPE = issue :MISSING_TYPE do
    "#{label.a_an_uc(semantic)} has no type"
  end

  # @api public
  MULTIBIND_NOT_COLLECTION_PRODUCER = issue :MULTIBIND_NOT_COLLECTION_PRODUCER, :actual_producer do
    "#{label.a_an_uc(semantic)} must have a MultibindProducerDescriptor, but got: #{label.a_an(actual_producer)}"
  end

  # @api public
  MULTIBIND_TYPE_ERROR = issue :MULTIBIND_TYPE_ERROR, :actual_type do
    "#{label.a_an_uc(semantic)} is expected to bind a collection type, but got: #{label.a_an(actual_type)}."
  end

  # @api public
  MISSING_BINDINGS = issue :MISSING_BINDINGS do
    "#{label.a_an_uc(semantic)} has zero bindings"
  end

  # @api public
  MISSING_BINDINGS_NAME = issue :MISSING_BINDINGS_NAME do
    "#{label.a_an_uc(semantic)} has no name"
  end

  # @api public
  MISSING_PREDICATES = issue :MISSING_PREDICATES do
    "#{label.a_an_uc(semantic)} has zero predicates"
  end

  # @api public
  MISSING_LAYERS = issue :MISSING_LAYERS do
    "#{label.a_an_uc(semantic)} has zero layers"
  end

  # @api public
  MISSING_LAYER_NAME = issue :MISSING_LAYER_NAME do
    "#{label.a_an_uc(semantic)} has a layer without name"
  end

  # @api public
  MISSING_BINDINGS_IN_LAYER = issue :MISSING_BINDINGS_IN_LAYER, :layer do
    "#{label.a_an_uc(semantic)} has zero bindings in #{label.label(layer)}"
  end

end
end
