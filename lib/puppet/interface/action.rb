# -*- coding: utf-8 -*-
require 'puppet/interface'
require 'puppet/interface/option'

class Puppet::Interface::Action
  def initialize(face, name, attrs = {})
    raise "#{name.inspect} is an invalid action name" unless name.to_s =~ /^[a-z]\w*$/
    @face    = face
    @name    = name.to_sym
    attrs.each do |k, v| send("#{k}=", v) end

    @options        = {}
    @when_rendering = {}
  end

  # This is not nice, but it is the easiest way to make us behave like the
  # Ruby Method object rather than UnboundMethod.  Duplication is vaguely
  # annoying, but at least we are a shallow clone. --daniel 2011-04-12
  def __dup_and_rebind_to(to)
    bound_version = self.dup
    bound_version.instance_variable_set(:@face, to)
    return bound_version
  end

  def to_s() "#{@face}##{@name}" end

  attr_reader   :name
  attr_accessor :default
  def default?
    !!@default
  end

  attr_accessor :summary


  ########################################################################
  # Support for rendering formats and all.
  def when_rendering(type)
    unless type.is_a? Symbol
      raise ArgumentError, "The rendering format must be a symbol, not #{type.class.name}"
    end
    return unless @when_rendering.has_key? type
    return @when_rendering[type].bind(@face)
  end
  def set_rendering_method_for(type, proc)
    unless proc.is_a? Proc
      msg = "The second argument to set_rendering_method_for must be a Proc"
      msg += ", not #{proc.class.name}" unless proc.nil?
      raise ArgumentError, msg
    end
    if proc.arity != 1 then
      msg = "when_rendering methods take one argument, the result, not "
      if proc.arity < 0 then
        msg += "a variable number"
      else
        msg += proc.arity.to_s
      end
      raise ArgumentError, msg
    end
    unless type.is_a? Symbol
      raise ArgumentError, "The rendering format must be a symbol, not #{type.class.name}"
    end
    if @when_rendering.has_key? type then
      raise ArgumentError, "You can't define a rendering method for #{type} twice"
    end
    # Now, the ugly bit.  We add the method to our interface object, and
    # retrieve it, to rotate through the dance of getting a suitable method
    # object out of the whole process. --daniel 2011-04-18
    @when_rendering[type] =
      @face.__send__( :__add_method, __render_method_name_for(type), proc)
  end

  def __render_method_name_for(type)
    :"#{name}_when_rendering_#{type}"
  end
  private :__render_method_name_for


  attr_accessor :render_as
  def render_as=(value)
    @render_as = value.to_sym
  end


  ########################################################################
  # Documentation stuff, whee!
  attr_accessor :summary, :description
  def summary=(value)
    value = value.to_s
    value =~ /\n/ and
      raise ArgumentError, "Face summary should be a single line; put the long text in 'description' instead."

    @summary = value
  end


  ########################################################################
  # Initially, this was defined to allow the @action.invoke pattern, which is
  # a very natural way to invoke behaviour given our introspection
  # capabilities.   Heck, our initial plan was to have the faces delegate to
  # the action object for invocation and all.
  #
  # It turns out that we have a binding problem to solve: @face was bound to
  # the parent class, not the subclass instance, and we don't pass the
  # appropriate context or change the binding enough to make this work.
  #
  # We could hack around it, by either mandating that you pass the context in
  # to invoke, or try to get the binding right, but that has probably got
  # subtleties that we don't instantly think of – especially around threads.
  #
  # So, we are pulling this method for now, and will return it to life when we
  # have the time to resolve the problem.  For now, you should replace...
  #
  #     @action = @face.get_action(name)
  #     @action.invoke(arg1, arg2, arg3)
  #
  # ...with...
  #
  #     @action = @face.get_action(name)
  #     @face.send(@action.name, arg1, arg2, arg3)
  #
  # I understand that is somewhat cumbersome, but it functions as desired.
  # --daniel 2011-03-31
  #
  # PS: This code is left present, but commented, to support this chunk of
  # documentation, for the benefit of the reader.
  #
  # def invoke(*args, &block)
  #   @face.send(name, *args, &block)
  # end


  # We need to build an instance method as a wrapper, using normal code, to be
  # able to expose argument defaulting between the caller and definer in the
  # Ruby API.  An extra method is, sadly, required for Ruby 1.8 to work since
  # it doesn't expose bind on a block.
  #
  # Hopefully we can improve this when we finally shuffle off the last of Ruby
  # 1.8 support, but that looks to be a few "enterprise" release eras away, so
  # we are pretty stuck with this for now.
  #
  # Patches to make this work more nicely with Ruby 1.9 using runtime version
  # checking and all are welcome, provided that they don't change anything
  # outside this little ol' bit of code and all.
  #
  # Incidentally, we though about vendoring evil-ruby and actually adjusting
  # the internal C structure implementation details under the hood to make
  # this stuff work, because it would have been cleaner.  Which gives you an
  # idea how motivated we were to make this cleaner.  Sorry.
  # --daniel 2011-03-31
  def when_invoked=(block)

    internal_name = "#{@name} implementation, required on Ruby 1.8".to_sym

    arity = block.arity
    if arity == 0 then
      # This will never fire on 1.8.7, which treats no arguments as "*args",
      # but will on 1.9.2, which treats it as "no arguments".  Which bites,
      # because this just begs for us to wind up in the horrible situation
      # where a 1.8 vs 1.9 error bites our end users. --daniel 2011-04-19
      raise ArgumentError, "action when_invoked requires at least one argument (options)"
    elsif arity > 0 then
      range = Range.new(1, arity - 1)
      decl = range.map { |x| "arg#{x}" } << "options = {}"
      optn = ""
      args = "[" + (range.map { |x| "arg#{x}" } << "options").join(", ") + "]"
    else
      range = Range.new(1, arity.abs - 1)
      decl = range.map { |x| "arg#{x}" } << "*rest"
      optn = "rest << {} unless rest.last.is_a?(Hash)"
      if arity == -1 then
        args = "rest"
      else
        args = "[" + range.map { |x| "arg#{x}" }.join(", ") + "] + rest"
      end
    end

    file    = __FILE__ + "+eval[wrapper]"
    line    = __LINE__ + 2 # <== points to the same line as 'def' in the wrapper.
    wrapper = <<WRAPPER
def #{@name}(#{decl.join(", ")})
  #{optn}
  args = #{args}
  options = args.last

  action = get_action(#{name.inspect})
  action.validate_args(args)
  __invoke_decorations(:before, action, args, options)
  rval = self.__send__(#{internal_name.inspect}, *args)
  __invoke_decorations(:after, action, args, options)
  return rval
end
WRAPPER

    if @face.is_a?(Class)
      @face.class_eval do eval wrapper, nil, file, line end
      @face.define_method(internal_name, &block)
    else
      @face.instance_eval do eval wrapper, nil, file, line end
      @face.meta_def(internal_name, &block)
    end
  end

  def add_option(option)
    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict}"
      elsif conflict = @face.get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict} on #{@face}"
      end
    end

    option.aliases.each do |name|
      @options[name] = option
    end

    option
  end

  def inherit_options_from(action)
    options = action.options.map { |opt| action.get_option(opt, false) }
    options.reject!(&:nil?).uniq.each { |option| add_option(option) }
  end

  def option?(name)
    @options.include? name.to_sym
  end

  def options
    (@options.keys + @face.options).sort
  end

  def get_option(name, with_inherited_options = true)
    option = @options[name.to_sym]
    if option.nil? and with_inherited_options
      option = @face.get_option(name)
    end
    option
  end

  def validate_args(args)
    required = options.map do |name|
      get_option(name)
    end.select(&:required?).collect(&:name) - args.last.keys

    return if required.empty?
    raise ArgumentError, "missing required options (#{required.join(', ')})"
  end

  ########################################################################
  # Support code for action decoration; see puppet/interface.rb for the gory
  # details of why this is hidden away behind private. --daniel 2011-04-15
  private
  def __add_method(name, proc)
    @face.__send__ :__add_method, name, proc
  end
end
