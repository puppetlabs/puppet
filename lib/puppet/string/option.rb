class Puppet::String::Option
  attr_reader :name, :string

  def initialize(string, name, attrs = {})
    raise "#{name.inspect} is an invalid option name" unless name.to_s =~ /^[a-z]\w*$/
    @string = string
    @name   = name.to_sym
    attrs.each do |k,v| send("#{k}=", v) end
  end

  def to_s
    @name.to_s.tr('_', '-')
  end

  Types = [:boolean, :string]
  def type
    @type ||= :boolean
  end
  def type=(input)
    value = begin input.to_sym rescue nil end
    Types.include?(value) or raise ArgumentError, "#{input.inspect} is not a valid type"
    @type = value
  end
end
