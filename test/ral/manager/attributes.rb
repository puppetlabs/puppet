#!/usr/bin/env ruby
require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'mocha'

class TestTypeAttributes < Test::Unit::TestCase
  include PuppetTest

  def mktype
    type = Puppet::Type.newtype(:faketype) {}
    cleanup { Puppet::Type.rmtype(:faketype) }
    type
  end

  def test_bracket_methods
    type = mktype

    # make a namevar
    type.newparam(:name) {}

    # make a property
    type.newproperty(:property) {}

    # and a param
    type.newparam(:param)

    inst = type.new(:name => "yay")

    # Make sure we can set each of them, including a metaparam
    [:param, :property, :noop].each do |param|
      assert_nothing_raised("Failed to set symbol") do
        inst[param] = true
      end

      assert_nothing_raised("Failed to set string") do
        inst[param.to_s] = true
      end

      if param == :property
        assert(inst.property(param), "did not get obj for #{param}")

              assert_equal(
        true, inst.should(param),
        
          "should value did not get set")
      else
        assert_equal(true, inst[param], "did not get correct value for #{param} from symbol")
        assert_equal(true, inst[param.to_s], "did not get correct value for #{param} from string")
      end
    end
  end

  def test_properties
    type = mktype

    # make a namevar
    type.newparam(:name) {}

    # make a couple of properties
    props = [:one, :two, :three]
    props.each do |prop|
      type.newproperty(prop) {}
    end

    inst = type.new(:name => "yay")

    inst[:one] = "boo"
    one = inst.property(:one)
    assert(one, "did not get obj for one")
    assert_equal([one], inst.send(:properties), "got wrong properties")

    inst[:three] = "rah"
    three = inst.property(:three)
    assert(three, "did not get obj for three")
    assert_equal([one, three], inst.send(:properties), "got wrong properties")

    inst[:two] = "whee"
    two = inst.property(:two)
    assert(two, "did not get obj for two")
    assert_equal([one, two, three], inst.send(:properties), "got wrong properties")
  end

  def attr_check(type)
    @num ||= 0
    @num += 1
    name = "name#{@num}"
    inst = type.new(:name => name)
    [:meta, :param, :prop].each do |name|
      klass = type.attrclass(name)
      assert(klass, "did not get class for #{name}")
      obj = yield inst, klass
      assert_instance_of(klass, obj, "did not get object back")

            assert_equal(
        "value", inst.value(klass.name),
        
        "value was not correct from value method")
      assert_equal("value", obj.value, "value was not correct")
    end
  end

  def test_newattr
    type = mktype
    type.newparam(:name) {}

    # Make one of each param type
    {
      :meta => :newmetaparam, :param => :newparam, :prop => :newproperty
    }.each do |name, method|
      assert_nothing_raised("Could not make #{name} of type #{method}") do
        type.send(method, name) {}
      end
    end

    # Now set each of them
    attr_check(type) do |inst, klass|
      property = inst.newattr(klass.name)
      property.value = "value"
      property
    end

    # Now try it passing the class in
    attr_check(type) do |inst, klass|
      property = inst.newattr(klass)
      property.value = "value"
      property
    end

    # Lastly, make sure we can create and then set, separately
    attr_check(type) do |inst, klass|
      obj = inst.newattr(klass.name)
      assert_nothing_raised("Could not set value after creation") do
        obj.value = "value"
      end

      # Make sure we can't create a new param object
      new_attr = inst.newattr(klass.name)
      assert_equal(new_attr, obj, "newattr should return the same object if called a second time")

      obj
    end
  end

  def test_alias_parameter
    type = mktype
    type.newparam(:name) {}
    type.newparam(:one) {}
    type.newproperty(:two) {}

    aliases = {
      :three => :one,
      :four => :two
    }
    aliases.each do |new, old|
      assert_nothing_raised("Could not create alias parameter #{new}") do
        type.set_attr_alias new => old
      end
    end

    aliases.each do |new, old|
      assert_equal(old, type.attr_alias(new), "did not return alias info for #{new}")
    end

    assert_nil(type.attr_alias(:name), "got invalid alias info for name")

    inst = type.new(:name => "my name")
    assert(inst, "could not create instance")

    aliases.each do |new, old|
      val = "value #{new}"
      assert_nothing_raised do
        inst[new] = val
      end

      case old
      when :one # param

              assert_equal(
        val, inst[new],
        
          "Incorrect alias value for #{new} in []")
      else
        assert_equal(val, inst.should(new), "Incorrect alias value for #{new} in should")
      end
      assert_equal(val, inst.value(new), "Incorrect alias value for #{new}")
      assert_equal(val, inst.value(old), "Incorrect orig value for #{old}")
    end
  end

  # Make sure newattr handles required features correctly.
  def test_newattr_and_required_features
    # Make a type with some features
    type = mktype
    type.feature :fone, "Something"
    type.feature :ftwo, "Something else"
    type.newparam(:name) {}

    # Make three properties: one with no requirements, one with one, and one with two
    none = type.newproperty(:none) {}
    one = type.newproperty(:one, :required_features => :fone) {}
    two = type.newproperty(:two, :required_features => [:fone, :ftwo]) {}

    # Now make similar providers
    nope = type.provide(:nope) {}
    maybe = type.provide(:maybe) { has_feature :fone}
    yep = type.provide(:yep) { has_features :fone, :ftwo}

    attrs = [:none, :one, :two]

    # Now make sure that we get warnings and no properties in those cases where our providers do not support the features requested
    [nope, maybe, yep].each_with_index do |prov, i|
      resource = type.new(:provider => prov.name, :name => "test#{i}", :none => "a", :one => "b", :two => "c")

      case prov.name
      when :nope
        yes = [:none]
        no = [:one, :two]
      when :maybe
        yes = [:none, :one]
        no = [:two]
      when :yep
        yes = [:none, :one, :two]
        no = []
      end
      yes.each { |a| assert(resource.should(a), "Did not get value for #{a} in #{prov.name}") }
      no.each do |a|
        assert_nil(resource.should(a), "Got value for unsupported %s in %s" % [a, prov.name])
        if Puppet::Util::Log.sendlevel?(:info)
          assert(@logs.find { |l| l.message =~ /not managing attribute #{a}/ and l.level == :info }, "No warning about failed %s" % a)
        end
      end

      @logs.clear
    end
  end

  # Make sure the 'check' metaparam just ignores non-properties, rather than failing.
  def test_check_allows_parameters
    file = Puppet::Type.type(:file)
    klass = file.attrclass(:check)

    resource = file.new(:path => tempfile)
    inst = klass.new(:resource => resource)

    {:property => [:owner, :group], :parameter => [:ignore, :recurse], :metaparam => [:require, :subscribe]}.each do |attrtype, attrs|
      assert_nothing_raised("Could not set check to a single #{attrtype} value") do
        inst.value = attrs[0]
      end

      if attrtype == :property
        assert(resource.property(attrs[0]), "Check did not create property instance during single check")
      end
      assert_nothing_raised("Could not set check to multiple #{attrtype} values") do
        inst.value = attrs
      end
      if attrtype == :property
        assert(resource.property(attrs[1]), "Check did not create property instance during multiple check")
      end
    end

    # But make sure actually invalid attributes fail
    assert_raise(Puppet::Error, ":check did not fail on invalid attribute") do
      inst.value = :nosuchattr
    end
  end

  def test_check_ignores_unsupported_params
    type = Puppet::Type.newtype(:unsupported) do
      feature :nosuchfeat, "testing"
      newparam(:name) {}
      newproperty(:yep) {}
      newproperty(:nope,  :required_features => :nosuchfeat) {}
    end
    $yep = :absent
    type.provide(:only) do
      def self.supports_parameter?(param)
        param.name != :nope
      end

      def yep
        $yep
      end
      def yep=(v)
        $yep = v
      end
    end
    cleanup { Puppet::Type.rmtype(:unsupported) }

    obj = type.new(:name => "test", :check => :yep)
    obj.stubs(:newattr).returns(stub_everything("newattr"))
    obj.expects(:newattr).with(:nope).never
    obj[:check] = :all
  end
end

