require 'puppettest'

module PuppetTest
    # A baseclass for the faketypes.
    class FakeModel
        class << self
            attr_accessor :name
            @name = :fakemodel
        end

        def self.validstates
            Puppet::Type.type(@name).validstates
        end

        def self.validstate?(name)
            Puppet::Type.type(@name).validstate?(name)
        end

        def self.to_s
            "Fake%s" % @name.to_s.capitalize
        end

        def [](param)
            if @realmodel.attrtype(param) == :state
                @is[param]
            else
                @params[param]
            end
        end

        def []=(param, value)
            unless @realmodel.attrtype(param)
                raise Puppet::DevError, "Invalid attribute %s for %s" %
                    [param, @realmodel.name]
            end
            if @realmodel.attrtype(param) == :state
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
            self[:name] = name
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
            @model.validstates.each do |state|
                ary << state unless ary.include? state
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

    @@fakemodels = {}
    @@fakeproviders = {}

    def fakemodel(type, name, options = {})
        type = type.intern if type.is_a? String
        unless @@fakemodels.include? type
            @@fakemodels[type] = Class.new(FakeModel)
            @@fakemodels[type].name = type
        end

        obj = @@fakemodels[type].new(name)
        obj[:name] = name
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
