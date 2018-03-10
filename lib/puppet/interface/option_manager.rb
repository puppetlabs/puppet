# This class is not actually public API, but the method
# {Puppet::Interface::OptionManager#option option} is public when used
# as part of the Faces DSL (i.e. from within a
# {Puppet::Interface.define define} block).
# @api public
module Puppet::Interface::OptionManager

  # @api private
  def display_global_options(*args)
    @display_global_options ||= []
    [args].flatten.each do |refopt|
      unless Puppet.settings.include?(refopt)
        #TRANSLATORS 'Puppet.settings' references to the Puppet settings options and should not be translated
        raise ArgumentError, _("Global option %{option} does not exist in Puppet.settings") % { option: refopt }
      end
      @display_global_options << refopt if refopt
    end
    @display_global_options.uniq!
    @display_global_options
  end
  alias :display_global_option :display_global_options

  def all_display_global_options
    walk_inheritance_tree(@display_global_options, :all_display_global_options)
  end

  # @api private
  def walk_inheritance_tree(start, sym)
    result = (start || [])
    if self.is_a?(Class) and superclass.respond_to?(sym)
      result = superclass.send(sym) + result
    elsif self.class.respond_to?(sym)
      result = self.class.send(sym) + result
    end
    return result
  end

  # Declare that this app can take a specific option, and provide the
  # code to do so. See {Puppet::Interface::ActionBuilder#option} for
  # details.
  #
  # @api public
  # @dsl Faces
  def option(*declaration, &block)
    add_option Puppet::Interface::OptionBuilder.build(self, *declaration, &block)
  end

  # @api private
  def add_option(option)
    # @options collects the added options in the order they're declared.
    # @options_hash collects the options keyed by alias for quick lookups.
    @options      ||= []
    @options_hash ||= {}

    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, _("Option %{option} conflicts with existing option %{conflict}") %
            { option: option, conflict: conflict }
      end

      actions.each do |action|
        action = get_action(action)
        if conflict = action.get_option(name) then
          raise ArgumentError, _("Option %{option} conflicts with existing option %{conflict} on %{action}") %
              { option: option, conflict: conflict, action: action }
        end
      end
    end

    @options << option.name

    option.aliases.each do |name|
      @options_hash[name] = option
    end

    return option
  end

  # @api private
  def options
    walk_inheritance_tree(@options, :options)
  end

  # @api private
  def get_option(name, with_inherited_options = true)
    @options_hash ||= {}

    result = @options_hash[name.to_sym]
    if result.nil? and with_inherited_options then
      if self.is_a?(Class) and superclass.respond_to?(:get_option)
        result = superclass.get_option(name)
      elsif self.class.respond_to?(:get_option)
        result = self.class.get_option(name)
      end
    end

    return result
  end

  # @api private
  def option?(name)
    options.include? name.to_sym
  end
end
