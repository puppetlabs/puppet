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
    block and instance_eval(&block)
    @option
  end

  # Metaprogram the simple DSL from the option class.
  Puppet::Interface::Option.instance_methods.grep(/=$/).each do |setter|
    next if setter =~ /^=/      # special case, darn it...

    dsl = setter.sub(/=$/, '')
    define_method(dsl) do |value| @option.send(setter, value) end
  end
end
