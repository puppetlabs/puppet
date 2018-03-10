require 'puppet/util/methodhelper'
require 'prettyprint'

# This represents an action that is attached to a face. Actions should
# be constructed by calling {Puppet::Interface::ActionManager#action},
# which is available on {Puppet::Interface}, and then calling methods of
# {Puppet::Interface::ActionBuilder} in the supplied block.
# @api private
class Puppet::Interface::Action
  include Puppet::Util::MethodHelper
  extend  Puppet::Interface::DocGen
  include Puppet::Interface::FullDocs

  # @api private
  def initialize(face, name, attrs = {})
    raise "#{name.inspect} is an invalid action name" unless name.to_s =~ /^[a-z]\w*$/
    @face    = face
    @name    = name.to_sym

    # The few bits of documentation we actually demand.  The default license
    # is a favour to our end users; if you happen to get that in a core face
    # report it as a bug, please. --daniel 2011-04-26
    @authors = []
    @license  = 'All Rights Reserved'

    set_options(attrs)

    # @options collects the added options in the order they're declared.
    # @options_hash collects the options keyed by alias for quick lookups.
    @options        = []
    @display_global_options = []
    @options_hash   = {}
    @when_rendering = {}
  end

  # This is not nice, but it is the easiest way to make us behave like the
  # Ruby Method object rather than UnboundMethod.  Duplication is vaguely
  # annoying, but at least we are a shallow clone. --daniel 2011-04-12

  # @return [void]
  # @api private
  def __dup_and_rebind_to(to)
    bound_version = self.dup
    bound_version.instance_variable_set(:@face, to)
    return bound_version
  end

  def to_s() "#{@face}##{@name}" end

  # The name of this action
  # @return [Symbol]
  attr_reader   :name

  # The face this action is attached to
  # @return [Puppet::Interface]
  attr_reader   :face

  # Whether this is the default action for the face
  # @return [Boolean]
  # @api private
  attr_accessor :default
  def default?
    !!@default
  end

  ########################################################################
  # Documentation...
  attr_doc :returns
  attr_doc :arguments
  def synopsis
    build_synopsis(@face.name, default? ? nil : name, arguments)
  end

  ########################################################################
  # Support for rendering formats and all.


  # @api private
  def when_rendering(type)
    unless type.is_a? Symbol
      raise ArgumentError, _("The rendering format must be a symbol, not %{class_name}") % { class_name: type.class.name }
    end
    # Do we have a rendering hook for this name?
    return @when_rendering[type].bind(@face) if @when_rendering.has_key? type

    # How about by another name?
    alt = type.to_s.sub(/^to_/, '').to_sym
    return @when_rendering[alt].bind(@face) if @when_rendering.has_key? alt

    # Guess not, nothing to run.
    return nil
  end

  # @api private
  def set_rendering_method_for(type, proc)
    unless proc.is_a? Proc
      msg = if proc.nil?
              #TRANSLATORS 'set_rendering_method_for' and 'Proc' should not be translated
              _("The second argument to set_rendering_method_for must be a Proc")
            else
              #TRANSLATORS 'set_rendering_method_for' and 'Proc' should not be translated
              _("The second argument to set_rendering_method_for must be a Proc, not %{class_name}") %
                  { class_name: proc.class.name }
            end
      raise ArgumentError, msg
    end

    if proc.arity != 1 and proc.arity != (@positional_arg_count + 1)
      msg = if proc.arity < 0 then
              #TRANSLATORS 'when_rendering', 'when_invoked' are method names and should not be translated
              _("The when_rendering method for the %{face} face %{name} action takes either just one argument,"\
                  " the result of when_invoked, or the result plus the %{arg_count} arguments passed to the"\
                  " when_invoked block, not a variable number") %
                  { face: @face.name, name: name, arg_count: @positional_arg_count }
            else
              #TRANSLATORS 'when_rendering', 'when_invoked' are method names and should not be translated
              _("The when_rendering method for the %{face} face %{name} action takes either just one argument,"\
                  " the result of when_invoked, or the result plus the %{arg_count} arguments passed to the"\
                  " when_invoked block, not %{string}") %
                  { face: @face.name, name: name, arg_count: @positional_arg_count, string: proc.arity.to_s }
            end
      raise ArgumentError, msg
    end
    unless type.is_a? Symbol
      raise ArgumentError, _("The rendering format must be a symbol, not %{class_name}") % { class_name: type.class.name }
    end
    if @when_rendering.has_key? type then
      raise ArgumentError, _("You can't define a rendering method for %{type} twice") % { type: type }
    end
    # Now, the ugly bit.  We add the method to our interface object, and
    # retrieve it, to rotate through the dance of getting a suitable method
    # object out of the whole process. --daniel 2011-04-18
    @when_rendering[type] =
      @face.__send__( :__add_method, __render_method_name_for(type), proc)
  end

  # @return [void]
  # @api private
  def __render_method_name_for(type)
    :"#{name}_when_rendering_#{type}"
  end
  private :__render_method_name_for


  # @api private
  # @return [Symbol]
  attr_accessor :render_as
  def render_as=(value)
    @render_as = value.to_sym
  end

  # @api private
  # @return [void]
  def deprecate
    @deprecated = true
  end

  # @api private
  # @return [Boolean]
  def deprecated?
    @deprecated
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


  # The arity of the action
  # @return [Integer]
  attr_reader   :positional_arg_count

  # The block that is executed when the action is invoked
  # @return [block]
  attr_accessor :when_invoked
  def when_invoked=(block)

    internal_name = "#{@name} implementation, required on Ruby 1.8".to_sym

    arity = @positional_arg_count = block.arity
    if arity == 0 then
      # This will never fire on 1.8.7, which treats no arguments as "*args",
      # but will on 1.9.2, which treats it as "no arguments".  Which bites,
      # because this just begs for us to wind up in the horrible situation
      # where a 1.8 vs 1.9 error bites our end users. --daniel 2011-04-19
      #TRANSLATORS 'when_invoked' should not be translated
      raise ArgumentError, _("when_invoked requires at least one argument (options) for action %{name}") % { name: @name }
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
  args    = #{args}
  action  = get_action(#{name.inspect})
  args   << action.validate_and_clean(args.pop)
  __invoke_decorations(:before, action, args, args.last)
  rval = self.__send__(#{internal_name.inspect}, *args)
  __invoke_decorations(:after, action, args, args.last)
  return rval
end
WRAPPER

    if @face.is_a?(Class)
      @face.class_eval do eval wrapper, nil, file, line end
      @face.send(:define_method, internal_name, &block)
      @when_invoked = @face.instance_method(name)
    else
      @face.instance_eval do eval wrapper, nil, file, line end
      @face.meta_def(internal_name, &block)
      @when_invoked = @face.method(name).unbind
    end
  end

  def add_option(option)
    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, _("Option %{option} conflicts with existing option %{conflict}") %
            { option: option, conflict: conflict }
      elsif conflict = @face.get_option(name) then
        raise ArgumentError, _("Option %{option} conflicts with existing option %{conflict} on %{face}") %
            { option: option, conflict: conflict, face: @face }
      end
    end

    @options << option.name

    option.aliases.each do |name|
      @options_hash[name] = option
    end

    option
  end

  def option?(name)
    @options_hash.include? name.to_sym
  end

  def options
    @face.options + @options
  end

  def add_display_global_options(*args)
    @display_global_options ||= []
    [args].flatten.each do |refopt|
      unless Puppet.settings.include? refopt
        #TRANSLATORS 'Puppet.settings' should not be translated
        raise ArgumentError, _("Global option %{option} does not exist in Puppet.settings") % { option: refopt }
      end
      @display_global_options << refopt
    end
    @display_global_options.uniq!
    @display_global_options
  end

  def display_global_options(*args)
    args ? add_display_global_options(args) : @display_global_options + @face.display_global_options
  end
  alias :display_global_option :display_global_options

  def get_option(name, with_inherited_options = true)
    option = @options_hash[name.to_sym]
    if option.nil? and with_inherited_options
      option = @face.get_option(name)
    end
    option
  end

  def validate_and_clean(original)
    # The final set of arguments; effectively a hand-rolled shallow copy of
    # the original, which protects the caller from the surprises they might
    # get if they passed us a hash and we mutated it...
    result = {}

    # Check for multiple aliases for the same option, and canonicalize the
    # name of the argument while we are about it.
    overlap = Hash.new do |h, k| h[k] = [] end
    unknown = []
    original.keys.each do |name|
      if option = get_option(name) then
        canonical = option.name
        if result.has_key? canonical
          overlap[canonical] << name
        else
          result[canonical] = original[name]
        end
      elsif Puppet.settings.include? name
        result[name] = original[name]
      else
        unknown << name
      end
    end

    unless overlap.empty?
      overlap_list = overlap.map {|k, v| "(#{k}, #{v.sort.join(', ')})" }.join(", ")
      raise ArgumentError, _("Multiple aliases for the same option passed: %{overlap_list}") %
          { overlap_list: overlap_list }
    end

    unless unknown.empty?
      unknown_list = unknown.sort.join(", ")
      raise ArgumentError, _("Unknown options passed: %{unknown_list}") % { unknown_list: unknown_list }
    end

    # Inject default arguments and check for missing mandating options.
    missing = []
    options.map {|x| get_option(x) }.each do |option|
      name = option.name
      next if result.has_key? name

      if option.has_default?
        result[name] = option.default
      elsif option.required?
        missing << name
      end
    end

    unless missing.empty?
      missing_list = missing.sort.join(', ')
      raise ArgumentError, _("The following options are required: %{missing_list}") % { missing_list: missing_list }
    end

    # All done.
    return result
  end

  ########################################################################
  # Support code for action decoration; see puppet/interface.rb for the gory
  # details of why this is hidden away behind private. --daniel 2011-04-15
  private
  # @return [void]
  # @api private
  def __add_method(name, proc)
    @face.__send__ :__add_method, name, proc
  end
end
