require 'puppet/faces'
require 'puppet/faces/action'

class Puppet::Faces::ActionBuilder
  attr_reader :action

  def self.build(face, name, &block)
    raise "Action #{name.inspect} must specify a block" unless block
    new(face, name, &block).action
  end

  private
  def initialize(face, name, &block)
    @face   = face
    @action = Puppet::Faces::Action.new(face, name)
    instance_eval(&block)
  end

  # Ideally the method we're defining here would be added to the action, and a
  # method on the face would defer to it, but we can't get scope correct, so
  # we stick with this. --daniel 2011-03-24
  def when_invoked(&block)
    raise "when_invoked on an ActionBuilder with no corresponding Action" unless @action
    @action.when_invoked = block
  end

  def option(*declaration, &block)
    option = Puppet::Faces::OptionBuilder.build(@action, *declaration, &block)
    @action.add_option(option)
  end
end
