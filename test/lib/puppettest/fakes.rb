require File.expand_path(File.join(File.dirname(__FILE__), '../../../lib/puppet/util'))

module PuppetTest
  # A baseclass for the faketypes.
  class FakeModel
    include Puppet::Util
    class << self
      attr_accessor :name, :realresource
      @name = :fakeresource
    end

    def self.key_attributes
      @realresource.key_attributes
    end

    def self.validproperties
      Puppet::Type.type(@name).validproperties
    end

    def self.validproperty?(name)
      Puppet::Type.type(@name).validproperty?(name)
    end

    def self.to_s
      "Fake#{@name.to_s.capitalize}"
    end

    def [](param)
      if @realresource.attrtype(param) == :property
        @is[param]
      else
        @params[param]
      end
    end

    def []=(param, value)
      param = symbolize(param)
      raise Puppet::DevError, "Invalid attribute #{param} for #{@realresource.name}" unless @realresource.valid_parameter?(param)
      if @realresource.attrtype(param) == :property
        @should[param] = value
      else
        @params[param] = value
      end
    end

    def initialize(name)
      @realresource = Puppet::Type.type(self.class.name)
      raise "Could not find type #{self.class.name}" unless @realresource
      @is = {}
      @should = {}
      @params = {}
      self[@realresource.key_attributes.first] = name
    end

    def inspect
      "#{self.class.to_s.sub(/.+::/, '')}(#{super()})"
    end

    def is(param)
      @is[param]
    end

    def should(param)
      @should[param]
    end

    def to_hash
      hash = @params.dup
      [@is, @should].each do |h|
        h.each do |p, v|
          hash[p] = v
        end
      end
      hash
    end

    def name
      self[:name]
    end
  end

  class FakeProvider
    attr_accessor :resource
    class << self
      attr_accessor :name, :resource_type, :methods
    end

    # A very low number, so these never show up as defaults via the standard
    # algorithms.
    def self.defaultnum
      -50
    end

    # Set up methods to fake things
    def self.apimethods(*ary)
      @resource_type.validproperties.each do |property|
        ary << property unless ary.include? property
      end
      attr_accessor(*ary)

      @methods = ary
    end

    def self.default?
      false
    end

    def self.initvars
      @calls = Hash.new do |hash, key|
        hash[key] = 0
      end
    end

    def self.source
      self.name
    end

    def self.supports_parameter?(param)
      true
    end

    def self.suitable?
      true
    end

    def clear
      @resource = nil
    end

    def initialize(resource)
      @resource = resource
    end

    def properties
      self.class.resource_type.validproperties.inject({}) do |props, name|
        props[name] = self.send(name) || :absent
        props
      end
    end
  end

  class FakeParsedProvider < FakeProvider
    def hash
      ret = {}
      instance_variables.each do |v|
        v = v.sub("@", '')
        if val = self.send(v)
          ret[v.intern] = val
        end
      end

      ret
    end

    def store(hash)
      hash.each do |n, v|
        method = n.to_s + "="
        send(method, v) if respond_to? method
      end
    end
  end

  @@fakeresources = {}
  @@fakeproviders = {}

  def fakeresource(type, name, options = {})
    type = type.intern if type.is_a? String
    unless @@fakeresources.include? type
      @@fakeresources[type] = Class.new(FakeModel)
      @@fakeresources[type].name = type

      resource = Puppet::Type.type(type)
      raise("Could not find type #{type}") unless resource
      @@fakeresources[type].realresource = resource
    end

    obj = @@fakeresources[type].new(name)
    options.each do |name, val|
      obj[name] = val
    end
    obj
  end

  module_function :fakeresource

  def fakeprovider(type, resource)
    type = type.intern if type.is_a? String
    unless @@fakeproviders.include? type
      @@fakeproviders[type] = Class.new(FakeModel) do
        @name = type
      end
    end

    @@fakeproviders[type].new(resource)
  end

  module_function :fakeprovider
end

