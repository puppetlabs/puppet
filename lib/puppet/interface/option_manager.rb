require 'puppet/interface/option_builder'

module Puppet::Interface::OptionManager
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
    result = (@options ||= [])

    if self.is_a?(Class) and superclass.respond_to?(:options)
      result = superclass.options + result
    elsif self.class.respond_to?(:options)
      result = self.class.options + result
    end

    return result
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
