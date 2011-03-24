require 'puppet/string/option_builder'

module Puppet::String::OptionManager
  # Declare that this app can take a specific option, and provide
  # the code to do so.
  def option(name, attrs = {}, &block)
    @options ||= {}
    raise ArgumentError, "Option #{name} already defined for #{self}" if option?(name)
    actions.each do |action|
      if get_action(action).option?(name) then
        raise ArgumentError, "Option #{name} already defined on action #{action} for #{self}"
      end
    end
    option = Puppet::String::OptionBuilder.build(self, name, &block)
    @options[option.name] = option
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

  def get_option(name)
    @options ||= {}
    result = @options[name.to_sym]
    unless result then
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
