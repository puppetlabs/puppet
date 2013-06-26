module Puppet::Pops::Binder::BinderIssues

  # NOTE: The methods #issue and #hard_issue are done in a somewhat funny way
  # since the Puppet::Pops::Issues is a module with these methods defined on the module-class
  # This makes it hard to inherit them in this module. (Likewise if Issues was a class, and they
  # need to be defined for the class, and such methods are also not inherited, it becomes more
  # difficult to reuse these. It did not seem as a good idea to refactor Issues at this point
  # in time - they should both probably be refactored once bindings support is finished.
  # Meanwhile, they delegate to Issues.

  # TODO: This class is just starting its life. Most notably there is no way to give more detailed
  # information about a binding - this remains to be designed.

  # (see Puppet::Pops::Issues#issue)
  def self.issue (issue_code, *args, &block)
    Puppet::Pops::Issues.issue(issue_code, *args, &block)
  end

  # (see Puppet::Pops::Issues#hard_issue)
  def self.hard_issue(issue_code, *args, &block)
    Puppet::Pops::Issues.hard_issue(issue_code, *args, &block)
  end

  MISSING_PRODUCER = issue :MISSING_PRODUCER do
    # TODO: improve error message with details that identifies the binding
    "binding has no producer"
  end

  MISSING_TYPE = issue :MISSING_TYPE do
    # TODO: improve error message with details that identifies the binding
    "binding has no type"
  end

  INCOMPATIBLE_TYPE = issue :INCOMPATIBLE_TYPE, :expected_type, :actual_type do
    # TODO: improve error message with details that identifies the binding
    "Incompatible type: expected #{label.a_an(expected_type)}, but got #{label.a_an(actual_type)}."
  end

  MULTIBIND_TYPE_ERROR = issue :MULTIBIND_TYPE_ERROR, :actual_type do
    "Multibind type error, expected multibind to have Array or Hash type, but got: #{label.a_an(actual_type)}."
  end

  MULTIBIND_NOT_ARRAY_PRODUCER = issue :MULTIBIND_NOT_ARRAY_PRODUCER, :actual_producer do
    "A Multibind of Array type must have an ArrayMultibindProducer, but got: #{label.a_an(actual_producer)}"
  end

  MULTIBIND_NOT_HASH_PRODUCER = issue :MULTIBIND_NOT_HASH_PRODUCER, :actual_producer do
    "A Multibind of Hash type must have a HashMultibindProducer, but got: #{label.a_an(actual_producer)}"
  end
end