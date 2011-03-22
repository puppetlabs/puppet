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
  # method on the interface would defer to it
  def invoke(&block)
    raise "Invoke called on an ActionBuilder with no corresponding Action" unless @action
    if @interface.is_a?(Class)
      @interface.define_method(@action.name, &block)
    else
      @interface.meta_def(@action.name, &block)
    end
  end
end
