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
    actions.include?(name)
  end
end
