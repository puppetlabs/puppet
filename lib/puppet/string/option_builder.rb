require 'puppet/string/option'

class Puppet::String::OptionBuilder
  attr_reader :option

  def self.build(string, name, attrs = {}, &block)
    new(string, name, attrs, &block).option
  end

  private
  def initialize(string, name, attrs, &block)
    @string = string
    @option = Puppet::String::Option.new(string, name, attrs)
    block and instance_eval(&block)
    @option
  end

  # Metaprogram the simple DSL from the option class.
  Puppet::String::Option.instance_methods.grep(/=$/).each do |setter|
    next if setter =~ /^=/      # special case, darn it...

    dsl = setter.sub(/=$/, '')
    define_method(dsl) do |value| @option.send(setter, value) end
  end
end
