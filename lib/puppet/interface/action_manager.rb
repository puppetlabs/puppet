module Puppet::Interface::ActionManager
  # Declare that this app can take a specific action, and provide
  # the code to do so.
  def action(name, &block)
    @actions ||= []
    name = name.to_s.downcase.to_sym
    raise "Action #{name} already defined for #{self}" if action?(name)

    @actions << name
    if self.is_a?(Class)
      define_method(name, &block)
    else
      meta_def(name, &block)
    end
  end

  def actions
    @actions ||= []
    result = @actions.dup

    if self.is_a?(Class) and superclass.respond_to?(:actions)
      result += superclass.actions
    elsif self.class.respond_to?(:actions)
      result += self.class.actions
    end
    result.sort { |a,b| a.to_s <=> b.to_s }
  end

  def action?(name)
    actions.include?(name.to_sym)
  end
end
