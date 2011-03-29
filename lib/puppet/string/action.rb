require 'puppet/string'
require 'puppet/string/option'

class Puppet::String::Action
  attr_reader :name

  def to_s
    "#{@string}##{@name}"
  end

  def initialize(string, name, attrs = {})
    raise "#{name.inspect} is an invalid action name" unless name.to_s =~ /^[a-z]\w*$/
    @string  = string
    @name    = name.to_sym
    @options = {}
    attrs.each do |k,v| send("#{k}=", v) end
  end

  def invoke(*args, &block)
    @string.method(name).call(*args,&block)
  end

  def invoke=(block)
    if @string.is_a?(Class)
      @string.define_method(@name, &block)
    else
      @string.meta_def(@name, &block)
    end
  end

  def add_option(option)
    option.aliases.each do |name|
      if conflict = get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict}"
      elsif conflict = @string.get_option(name) then
        raise ArgumentError, "Option #{option} conflicts with existing option #{conflict} on #{@string}"
      end
    end

    option.aliases.each do |name|
      @options[name] = option
    end

    option
  end

  def option?(name)
    @options.include? name.to_sym
  end

  def options
    (@options.keys + @string.options).sort
  end

  def get_option(name)
    @options[name.to_sym] || @string.get_option(name)
  end
end
