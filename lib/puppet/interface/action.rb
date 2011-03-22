require 'puppet/interface'

class Puppet::Interface::Action
  attr_reader :name

  def initialize(interface, name)
    name = name.to_s
    raise "'#{name}' is an invalid action name" unless name =~ /^[a-z]\w*$/
    @interface = interface
    @name = name
  end

  def invoke(*args, &block)
    @interface.method(name).call(*args,&block)
  end
end
