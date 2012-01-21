require 'puppet/interface/option'

class Puppet::Interface::OptionBuilder
  attr_reader :option

  def self.build(face, *declaration, &block)
    new(face, *declaration, &block).option
  end

  private
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

  def after_action(&block)
    block or raise ArgumentError, "#{@option} after_action requires a block"
    if @option.after_action
      raise ArgumentError, "#{@option} already has a after_action set"
    end
    unless block.arity == 3 then
      raise ArgumentError, "after_action takes three arguments, action, args, and options"
    end
    @option.after_action = block
  end

  def required(value = true)
    @option.required = value
  end

  def default_to(&block)
    block or raise ArgumentError, "#{@option} default_to requires a block"
    if @option.has_default?
      raise ArgumentError, "#{@option} already has a default value"
    end
    # Ruby 1.8 treats a block without arguments as accepting any number; 1.9
    # gets this right, so we work around it for now... --daniel 2011-07-20
    unless block.arity == 0 or (RUBY_VERSION =~ /^1\.8/ and block.arity == -1)
      raise ArgumentError, "#{@option} default_to block should not take any arguments"
    end
    @option.default = block
  end
end
