# This class is used to build {Puppet::Interface::Action actions}.
# When an action is defined with
# {Puppet::Interface::ActionManager#action} the block is evaluated
# within the context of a new instance of this class.
# @api public
class Puppet::Interface::ActionBuilder
  # The action under construction
  # @return [Puppet::Interface::Action]
  # @api private
  attr_reader :action

  # Builds a new action.
  # @return [Puppet::Interface::Action]
  # @api private
  def self.build(face, name, &block)
    raise "Action #{name.inspect} must specify a block" unless block
    new(face, name, &block).action
  end

  # Ideally the method we're defining here would be added to the action, and a
  # method on the face would defer to it, but we can't get scope correct, so
  # we stick with this. --daniel 2011-03-24

  # Sets what the action does when it is invoked. This takes a block
  # which will be called when the action is invoked. The action will
  # accept arguments based on the arity of the block. It should always
  # take at least one argument for options. Options will be the last
  # argument.
  #
  # @overload when_invoked({|options| ... })
  #   An action with no arguments
  # @overload when_invoked({|arg1, arg2, options| ... })
  #   An action with two arguments
  # @return [void]
  # @api public
  # @dsl Faces
  def when_invoked(&block)
    @action.when_invoked = block
  end

  # Sets a block to be run at the rendering stage, for a specific
  # rendering type (eg JSON, YAML, console), after the block for
  # when_invoked gets run. This manipulates the value returned by the
  # action. It makes it possible to work around limitations in the
  # underlying object returned, and should be avoided in favor of
  # returning a more capable object.
  # @api private
  # @todo this needs more
  # @dsl Faces
  def when_rendering(type = nil, &block)
    if type.nil? then           # the default error message sucks --daniel 2011-04-18
      raise ArgumentError, 'You must give a rendering format to when_rendering'
    end
    if block.nil? then
      raise ArgumentError, 'You must give a block to when_rendering'
    end
    @action.set_rendering_method_for(type, block)
  end

  # Declare that this action can take a specific option, and provide the
  # code to do so.  One or more strings are given, in the style of
  # OptionParser (see example). These strings are parsed to derive a
  # name for the option. Any `-` characters within the option name (ie
  # excluding the initial `-` or `--` for an option) will be translated
  # to `_`.The first long option will be used as the name, and the rest
  # are retained as aliases. The original form of the option is used
  # when invoking the face, the translated form is used internally.
  #
  # When the action is invoked the value of the option is available in
  # a hash passed to the {Puppet::Interface::ActionBuilder#when_invoked
  # when_invoked} block, using the option name in symbol form as the
  # hash key.
  #
  # The block to this method is used to set attributes for the option
  # (see {Puppet::Interface::OptionBuilder}).
  #
  # @param declaration [String] Option declarations, as described above
  #   and in the example.
  #
  # @example Say hi
  #   action :say_hi do
  #     option "-u USER", "--user-name USER" do
  #       summary "Who to say hi to"
  #     end
  #
  #     when_invoked do |options|
  #       "Hi, #{options[:user_name]}"
  #     end
  #   end
  # @api public
  # @dsl Faces
  def option(*declaration, &block)
    option = Puppet::Interface::OptionBuilder.build(@action, *declaration, &block)
    @action.add_option(option)
  end

  # Set this as the default action for the face.
  # @api public
  # @dsl Faces
  # @return [void]
  def default(value = true)
    @action.default = !!value
  end

  # @api private
  def display_global_options(*args)
    @action.add_display_global_options args
  end
  alias :display_global_option :display_global_options

  # Sets the default rendering format
  # @api private
  def render_as(value = nil)
    value.nil? and raise ArgumentError, "You must give a rendering format to render_as"

    formats = Puppet::Network::FormatHandler.formats
    unless formats.include? value
      raise ArgumentError, "#{value.inspect} is not a valid rendering format: #{formats.sort.join(", ")}"
    end

    @action.render_as = value
  end

  # Metaprogram the simple DSL from the target class.
  Puppet::Interface::Action.instance_methods.grep(/=$/).each do |setter|
    next if setter =~ /^=/
    property = setter.to_s.chomp('=')

    unless method_defined? property
      # Using eval because the argument handling semantics are less awful than
      # when we use the define_method/block version.  The later warns on older
      # Ruby versions if you pass the wrong number of arguments, but carries
      # on, which is totally not what we want. --daniel 2011-04-18
      eval <<-METHOD
        def #{property}(value)
          @action.#{property} = value
        end
      METHOD
    end
  end

  private
  def initialize(face, name, &block)
    @face   = face
    @action = Puppet::Interface::Action.new(face, name)
    instance_eval(&block)
    @action.when_invoked or raise ArgumentError, "actions need to know what to do when_invoked; please add the block"
  end
end
