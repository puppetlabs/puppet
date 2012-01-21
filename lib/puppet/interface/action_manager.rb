require 'puppet/interface/action'

module Puppet::Interface::ActionManager
  # Declare that this app can take a specific action, and provide
  # the code to do so.
  def action(name, &block)
    require 'puppet/interface/action_builder'

    @actions ||= {}
    raise "Action #{name} already defined for #{self}" if action?(name)

    action = Puppet::Interface::ActionBuilder.build(self, name, &block)

    if action.default and current = get_default_action
      raise "Actions #{current.name} and #{name} cannot both be default"
    end

    @actions[action.name] = action
  end

  # This is the short-form of an action definition; it doesn't use the
  # builder, just creates the action directly from the block.
  def script(name, &block)
    @actions ||= {}
    raise "Action #{name} already defined for #{self}" if action?(name)
    @actions[name] = Puppet::Interface::Action.new(self, name, :when_invoked => block)
  end

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
    result.uniq.sort
  end

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

  def get_default_action
    default = actions.map {|x| get_action(x) }.select {|x| x.default }
    if default.length > 1
      raise "The actions #{default.map(&:name).join(", ")} cannot all be default"
    end
    default.first
  end

  def action?(name)
    actions.include?(name.to_sym)
  end
end
