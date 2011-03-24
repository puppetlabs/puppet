require 'puppet/interface'

class Puppet::Interface::Action
  attr_reader :name

  def initialize(interface, name, attrs = {})
    name = name.to_s
    raise "'#{name}' is an invalid action name" unless name =~ /^[a-z]\w*$/

    attrs.each do |k,v| send("#{k}=", v) end
    @interface = interface
    @name = name
  end

  def invoke(*args, &block)
    @interface.method(name).call(*args,&block)
  end

  def invoke=(block)
    if @interface.is_a?(Class)
      @interface.define_method(@name, &block)
    else
      @interface.meta_def(@name, &block)
    end
  end
end
