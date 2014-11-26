# This class is not actually public API, but the method
# {Puppet::Interface::ActionManager#action action} is public when used
# as part of the Faces DSL (i.e. from within a
# {Puppet::Interface.define define} block).
# @api public
module Puppet::Interface::ActionManager
  # Declare that this app can take a specific action, and provide
  # the code to do so.

  # Defines a new action. This takes a block to build the action using
  # the methods on {Puppet::Interface::ActionBuilder}.
  # @param name [Symbol] The name that will be used to invoke the
  #   action
  # @overload action(name, {|| block})
  # @return [void]
  # @api public
  # @dsl Faces
  def action(name, &block)
    @actions ||= {}
    Puppet.warning "Redefining action #{name} for #{self}" if action?(name)

    action = Puppet::Interface::ActionBuilder.build(self, name, &block)

    # REVISIT: (#18042) doesn't this mean we can't redefine the default action? -- josh
    if action.default and current = get_default_action
      raise "Actions #{current.name} and #{name} cannot both be default"
    end

    @actions[action.name] = action
  end

  # Returns the list of available actions for this face.
  # @return [Array<Symbol>] The names of the actions for this face
  # @api private
  def actions
    @actions ||= {}
    result = @actions.keys

    if self.is_a?(Class) and superclass.respond_to?(:actions)
      result += superclass.actions
    elsif self.class.respond_to?(:actions)
      result += self.class.actions
    end
    # We need to uniq the result, because we duplicate actions when they are
    # fetched to ensure that they have the correct bindings; they shadow the
    # parent, and uniq implements that. --daniel 2011-06-01
    (result - @deactivated_actions.to_a).uniq.sort
  end

  # Retrieves a named action
  # @param name [Symbol] The name of the action
  # @return [Puppet::Interface::Action] The action object
  # @api private
  def get_action(name)
    @actions ||= {}
    result = @actions[name.to_sym]
    if result.nil?
      if self.is_a?(Class) and superclass.respond_to?(:get_action)
        found = superclass.get_action(name)
      elsif self.class.respond_to?(:get_action)
        found = self.class.get_action(name)
      end

      if found then
        # This is not the nicest way to make action equivalent to the Ruby
        # Method object, rather than UnboundMethod, but it will do for now,
        # and we only have to make this change in *one* place. --daniel 2011-04-12
        result = @actions[name.to_sym] = found.__dup_and_rebind_to(self)
      end
    end
    return result
  end

  # Retrieves the default action for the face
  # @return [Puppet::Interface::Action]
  # @api private
  def get_default_action
    default = actions.map {|x| get_action(x) }.select {|x| x.default }
    if default.length > 1
      raise "The actions #{default.map(&:name).join(", ")} cannot all be default"
    end
    default.first
  end

  # Deactivate a named action
  # @return [Puppet::Interface::Action]
  # @api public
  def deactivate_action(name)
    @deactivated_actions ||= Set.new
    @deactivated_actions.add name.to_sym
  end

  # @api private
  def action?(name)
    actions.include?(name.to_sym)
  end
end
