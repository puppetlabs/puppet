require 'puppet/interface/option_builder'

module Puppet::Interface::OptionManager
  
  def display_global_options(*args)
    @display_global_options ||= []
    [args].flatten.each do |refopt|
      raise ArgumentError, "Global option #{refopt} does not exist in Puppet.settings" unless Puppet.settings.include? refopt
      @display_global_options << refopt if refopt
    end
    @display_global_options.uniq!
    @display_global_options
  end
  alias :display_global_option :display_global_options
  
  def all_display_global_options
    walk_inheritance_tree(@display_global_options, :all_display_global_options)
  end
  
  def walk_inheritance_tree(start, sym)
    result = (start ||= [])
    if self.is_a?(Class) and superclass.respond_to?(sym)
      result = superclass.send(sym) + result
    elsif self.class.respond_to?(sym)
      result = self.class.send(sym) + result
    end
    return result
  end
  
  # Declare that this app can take a specific option, and provide
  # the code to do so.
  def option(*declaration, &block)
    add_option Puppet::Interface::OptionBuilder.build(self, *declaration, &block)
  end

  def add_option(option)
    # @options collects the added options in the order they're declared.
    # @options_hash collects the options keyed by alias for quick lookups.
    @options      ||= []
    @options_hash ||= {}

    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict}"
      end

      actions.each do |action|
        action = get_action(action)
        if conflict = action.get_option(name) then
          raise ArgumentError, "Option #{option} conflicts with existing option #{conflict} on #{action}"
        end
      end
    end

    @options << option.name

    option.aliases.each do |name|
      @options_hash[name] = option
    end

    return option
  end

  def options
    walk_inheritance_tree(@options, :options)
  end

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

  def option?(name)
    options.include? name.to_sym
  end
end
