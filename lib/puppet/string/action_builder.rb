require 'puppet/string'
require 'puppet/string/action'

class Puppet::String::ActionBuilder
  attr_reader :action

  def self.build(string, name, &block)
    raise "Action #{name.inspect} must specify a block" unless block
    new(string, name, &block).action
  end

  def initialize(string, name, &block)
    @string = string
    @action = Puppet::String::Action.new(string, name)
    instance_eval(&block)
  end

  # Ideally the method we're defining here would be added to the action, and a
  # method on the string would defer to it, but we can't get scope correct,
  # so we stick with this. --daniel 2011-03-24
  def invoke(&block)
    raise "Invoke called on an ActionBuilder with no corresponding Action" unless @action
    @action.invoke = block
  end

  def option(*declaration, &block)
    option = Puppet::String::OptionBuilder.build(@action, *declaration, &block)
    @action.add_option(option)
  end
end
