require 'puppettest'

module PuppetTest
    # A baseclass for the faketypes.
    class FakeModel
        include Puppet::Util
        class << self
            attr_accessor :name, :realmodel
            @name = :fakemodel
        end

        def self.namevar
            @realmodel.namevar
        end

        def self.validproperties
            Puppet::Type.type(@name).validproperties
        end

        def self.validproperty?(name)
            Puppet::Type.type(@name).validproperty?(name)
        end

        def self.to_s
            "Fake%s" % @name.to_s.capitalize
        end

        def [](param)
            if @realmodel.attrtype(param) == :property
                @is[param]
            else
                @params[param]
            end
        end

        def []=(param, value)
            param = symbolize(param)
            unless @realmodel.validattr?(param)
                raise Puppet::DevError, "Invalid attribute %s for %s" %
                    [param, @realmodel.name]
            end
            if @realmodel.attrtype(param) == :property
                @should[param] = value
            else
                @params[param] = value
            end
        end

        def initialize(name)
            @realmodel = Puppet::Type.type(self.class.name)
            raise "Could not find type #{self.class.name}" unless @realmodel
            @is = {}
            @should = {}
            @params = {}
            self[@realmodel.namevar] = name
        end

        def inspect
            "%s(%s)" % [self.class.to_s.sub(/.+::/, ''), super()]
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
        attr_accessor :model
        class << self
            attr_accessor :name, :model, :methods
        end

        # A very low number, so these never show up as defaults via the standard
        # algorithms.
        def self.defaultnum
            -50
        end

        # Set up methods to fake things
        def self.apimethods(*ary)
            @model.validproperties.each do |property|
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

        def self.supports_parameter?(param)
            true
        end

        def self.suitable?
            true
        end

        def clear
            @model = nil
        end

        def initialize(model)
            @model = model
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

            return ret
        end 

        def store(hash)
            hash.each do |n, v|
                method = n.to_s + "="
                if respond_to? method
                    send(method, v)
                end
            end
        end
    end

    @@fakemodels = {}
    @@fakeproviders = {}

    def fakemodel(type, name, options = {})
        type = type.intern if type.is_a? String
        unless @@fakemodels.include? type
            @@fakemodels[type] = Class.new(FakeModel)
            @@fakemodels[type].name = type

            model = Puppet::Type.type(type)
            raise("Could not find type %s" % type) unless model
            @@fakemodels[type].realmodel = model
        end

        obj = @@fakemodels[type].new(name)
        options.each do |name, val|
            obj[name] = val
        end
        obj
    end

    module_function :fakemodel

    def fakeprovider(type, model)
        type = type.intern if type.is_a? String
        unless @@fakeproviders.include? type
            @@fakeproviders[type] = Class.new(FakeModel) do
                @name = type
            end
        end

        @@fakeproviders[type].new(model)
    end

    module_function :fakeprovider
end

# $Id$
