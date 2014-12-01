# @api public
class Puppet::Interface::OptionBuilder
  # The option under construction
  # @return [Puppet::Interface::Option]
  # @api private
  attr_reader :option

  # Build an option
  # @return [Puppet::Interface::Option]
  # @api private
  def self.build(face, *declaration, &block)
    new(face, *declaration, &block).option
  end

  def initialize(face, *declaration, &block)
    @face   = face
    @option = Puppet::Interface::Option.new(face, *declaration)
    instance_eval(&block) if block_given?
    @option
  end

  # Metaprogram the simple DSL from the option class.
  Puppet::Interface::Option.instance_methods.grep(/=$/).each do |setter|
    next if setter =~ /^=/
    dsl = setter.to_s.chomp('=')

    unless private_method_defined? dsl
      define_method(dsl) do |value| @option.send(setter, value) end
    end
  end

  # Override some methods that deal in blocks, not objects.

  # Sets a block to be executed when an action is invoked before the
  # main action code. This is most commonly used to validate an option.
  # @yieldparam action [Puppet::Interface::Action] The action being
  #   invoked
  # @yieldparam args [Array] The arguments given to the action
  # @yieldparam options [Hash<Symbol=>Object>] Any options set
  # @api public
  # @dsl Faces
  def before_action(&block)
    block or raise ArgumentError, "#{@option} before_action requires a block"
    if @option.before_action
      raise ArgumentError, "#{@option} already has a before_action set"
    end
    unless block.arity == 3 then
      raise ArgumentError, "before_action takes three arguments, action, args, and options"
    end
    @option.before_action = block
  end

  # Sets a block to be executed after an action is invoked.
  # !(see before_action)
  # @api public
  # @dsl Faces
  def after_action(&block)
    block or raise ArgumentError, "#{@option} after_action requires a block"
    if @option.after_action
      raise ArgumentError, "#{@option} already has an after_action set"
    end
    unless block.arity == 3 then
      raise ArgumentError, "after_action takes three arguments, action, args, and options"
    end
    @option.after_action = block
  end

  # Sets whether the option is required. If no argument is given it
  # defaults to setting it as a required option.
  # @api public
  # @dsl Faces
  def required(value = true)
    @option.required = value
  end

  # Sets a block that will be used to compute the default value for this
  # option. It will be evaluated when the action is invoked. The block
  # should take no arguments.
  # @api public
  # @dsl Faces
  def default_to(&block)
    block or raise ArgumentError, "#{@option} default_to requires a block"
    if @option.has_default?
      raise ArgumentError, "#{@option} already has a default value"
    end
    unless block.arity == 0
      raise ArgumentError, "#{@option} default_to block should not take any arguments"
    end
    @option.default = block
  end
end
