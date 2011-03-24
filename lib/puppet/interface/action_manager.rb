require 'puppet/interface/action_builder'

module Puppet::Interface::ActionManager
  # Declare that this app can take a specific action, and provide
  # the code to do so.
  def action(name, &block)
    @actions ||= {}
    name = name.to_s.downcase.to_sym

    raise "Action #{name} already defined for #{self}" if action?(name)

    action = Puppet::Interface::ActionBuilder.build(self, name, &block)

    @actions[name] = action
  end

  # This is the short-form of an action definition; it doesn't use the
  # builder, just creates the action directly from the block.
  def script(name, &block)
    @actions ||= {}
    name = name.to_s.downcase.to_sym
    raise "Action #{name} already defined for #{self}" if action?(name)
    @actions[name] = Puppet::Interface::Action.new(self, name, :invoke => block)
  end

  def actions
    @actions ||= {}
    result = @actions.keys

    if self.is_a?(Class) and superclass.respond_to?(:actions)
      result += superclass.actions
    elsif self.class.respond_to?(:actions)
      result += self.class.actions
    end
    result.sort
  end

  def get_action(name)
    @actions[name].dup
  end

  def action?(name)
    actions.include?(name.to_sym)
  end
end
