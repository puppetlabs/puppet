require 'puppet/interface/option_builder'

module Puppet::Interface::OptionManager
  # Declare that this app can take a specific option, and provide
  # the code to do so.
  def option(*declaration, &block)
    add_option Puppet::Interface::OptionBuilder.build(self, *declaration, &block)
  end

  def add_option(option)
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

    option.aliases.each { |name| @options[name] = option }
    option
  end

  def options
    @options ||= {}
    result = @options.keys

    if self.is_a?(Class) and superclass.respond_to?(:options)
      result += superclass.options
    elsif self.class.respond_to?(:options)
      result += self.class.options
    end
    result.sort
  end

  def get_option(name, with_inherited_options = true)
    @options ||= {}
    result = @options[name.to_sym]
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
