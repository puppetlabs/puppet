require 'puppet/string'

class Puppet::String::Action
  attr_reader :name

  def to_s
    "#{@string}##{@name}"
  end

  def initialize(string, name, attrs = {})
    name = name.to_s
    raise "'#{name}' is an invalid action name" unless name =~ /^[a-z]\w*$/

    @string = string
    @name      = name
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
end
