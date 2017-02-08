# -*- coding: utf-8 -*-

module Puppet
  class Type
    class << self
      include Puppet::MetaType::Manager
    end

    # Creates a `validate` method that is used to validate a resource before it is operated on.
    # The validation should raise exceptions if the validation finds errors. (It is not recommended to
    # issue warnings as this typically just ends up in a logfile - you should fail if a validation fails).
    # The easiest way to raise an appropriate exception is to call the method {Puppet::Util::Errors.fail} with
    # the message as an argument.
    #
    # @yield [ ] a required block called with self set to the instance of a Type class representing a resource.
    # @return [void]
    # @dsl type
    # @api public
    #
    def self.validate(&block)
      define_method(:validate, &block)
    end
  end
end
