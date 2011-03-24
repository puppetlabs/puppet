require 'puppet/interface'
require 'puppet/interface/action'

class Puppet::Interface::ActionBuilder
  attr_reader :action

  def self.build(interface, name, &block)
    name = name.to_s
    raise "Action '#{name}' must specify a block" unless block
    builder = new(interface, name, &block)
    builder.action
  end

  def initialize(interface, name, &block)
    @interface = interface
    @action = Puppet::Interface::Action.new(interface, name)
    instance_eval(&block)
  end

  # Ideally the method we're defining here would be added to the action, and a
  # method on the interface would defer to it, but we can't get scope correct,
  # so we stick with this. --daniel 2011-03-24
  def invoke(&block)
    raise "Invoke called on an ActionBuilder with no corresponding Action" unless @action
    @action.invoke = block
  end
end
