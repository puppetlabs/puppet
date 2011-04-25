require 'puppet/interface'
require 'puppet/interface/action'

class Puppet::Interface::ActionBuilder
  attr_reader :action

  def self.build(face, name, &block)
    raise "Action #{name.inspect} must specify a block" unless block
    new(face, name, &block).action
  end

  private
  def initialize(face, name, &block)
    @face   = face
    @action = Puppet::Interface::Action.new(face, name)
    instance_eval(&block)
  end

  # Ideally the method we're defining here would be added to the action, and a
  # method on the face would defer to it, but we can't get scope correct, so
  # we stick with this. --daniel 2011-03-24
  def when_invoked(&block)
    @action.when_invoked = block
  end

  def when_rendering(type = nil, &block)
    if type.nil? then           # the default error message sucks --daniel 2011-04-18
      raise ArgumentError, 'You must give a rendering format to when_rendering'
    end
    if block.nil? then
      raise ArgumentError, 'You must give a block to when_rendering'
    end
    @action.set_rendering_method_for(type, block)
  end

  def option(*declaration, &block)
    option = Puppet::Interface::OptionBuilder.build(@action, *declaration, &block)
    @action.add_option(option)
  end

  def inherit_options_from(action)
    if action.is_a? Symbol
      name = action
      action = @face.get_action(name) or
      raise ArgumentError, "This Face has no action named #{name}!"
    end

    @action.inherit_options_from(action)
  end

  def default(value = true)
    @action.default = !!value
  end

  def render_as(value = nil)
    value.nil? and raise ArgumentError, "You must give a rendering format to render_as"

    formats = Puppet::Network::FormatHandler.formats << :for_humans
    unless formats.include? value
      raise ArgumentError, "#{value.inspect} is not a valid rendering format: #{formats.sort.join(", ")}"
    end

    @action.render_as = value
  end

  # Metaprogram the simple DSL from the target class.
  Puppet::Interface::Action.instance_methods.grep(/=$/).each do |setter|
    next if setter =~ /^=/
    dsl = setter.sub(/=$/, '')

    unless private_instance_methods.include? dsl
      # Using eval because the argument handling semantics are less awful than
      # when we use the define_method/block version.  The later warns on older
      # Ruby versions if you pass the wrong number of arguments, but carries
      # on, which is totally not what we want. --daniel 2011-04-18
      eval <<METHOD
def #{dsl}(value)
  @action.#{dsl} = value
end
METHOD
    end
  end
end
