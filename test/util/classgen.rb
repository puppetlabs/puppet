#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppettest'

class TestPuppetUtilClassGen < Test::Unit::TestCase
  include PuppetTest

  class FakeBase
    class << self
      attr_accessor :name
    end
  end

  class GenTest
    class << self
      include Puppet::Util::ClassGen
    end
  end

  def testclasses(name)
    sub = Class.new(GenTest) do @name = "base#{name.to_s}" end
    self.class.const_set("Base#{name.to_s}", sub)

    klass = Class.new(FakeBase) do @name = "gen#{name.to_s}"end

    return sub, klass
  end

  def test_handleclassconst
    sub, klass = testclasses("const")
    const = nil
    assert_nothing_raised do
      const = sub.send(:handleclassconst, klass, klass.name, {})
    end

    # make sure the constant is set
    assert(defined?(Baseconst::Genconst), "const was not defined")
    assert_equal(Baseconst::Genconst.object_id, klass.object_id)

    # Now make sure don't replace by default
    newklass = Class.new(FakeBase) do @name = klass.name end
    assert_raise(Puppet::ConstantAlreadyDefined) do
      const = sub.send(:handleclassconst, newklass, klass.name, {})
    end
    assert_equal(Baseconst::Genconst.object_id, klass.object_id)

    # Now make sure we can replace it
    assert_nothing_raised do
      const = sub.send(:handleclassconst, newklass, klass.name, :overwrite => true)
    end
    assert_equal(Baseconst::Genconst.object_id, newklass.object_id)

    # Now make sure we can choose our own constant
    assert_nothing_raised do

            const = sub.send(
        :handleclassconst, newklass, klass.name,
        
        :constant => "Fooness")
    end
    assert(defined?(Baseconst::Fooness), "Specified constant was not defined")

    # And make sure prefixes work
    assert_nothing_raised do

            const = sub.send(
        :handleclassconst, newklass, klass.name,
        
        :prefix => "Test")
    end
    assert(defined?(Baseconst::TestGenconst), "prefix was not used")
  end

  def test_initclass_preinit
    sub, klass = testclasses("preinit")

    class << klass
      attr_accessor :set
      def preinit
        @set = true
      end
    end

    assert(!klass.set, "Class was already initialized")

    assert_nothing_raised do sub.send(:initclass, klass, {}) end

    assert(klass.set, "Class was not initialized")
  end

  def test_initclass_initvars
    sub, klass = testclasses("initvars")

    class << klass
      attr_accessor :set
      def initvars
        @set = true
      end
    end

    assert(!klass.set, "Class was already initialized")

    assert_nothing_raised do sub.send(:initclass, klass, {}) end

    assert(klass.set, "Class was not initialized")
  end

  def test_initclass_attributes
    sub, klass = testclasses("attributes")

    class << klass
      attr_accessor :one, :two, :three
    end

    assert(!klass.one, "'one' was already set")


          assert_nothing_raised do sub.send(
        :initclass, klass,
        
      :attributes => {:one => :a, :two => :b}) end

    assert_equal(:a, klass.one, "Class was initialized incorrectly")
    assert_equal(:b, klass.two, "Class was initialized incorrectly")
    assert_nil(klass.three, "Class was initialized incorrectly")
  end

  def test_initclass_include_and_extend
    sub, klass = testclasses("include_and_extend")

    incl = Module.new do
      attr_accessor :included
    end
    self.class.const_set("Incl", incl)

    ext = Module.new do
      attr_accessor :extended
    end
    self.class.const_set("Ext", ext)

    assert(! klass.respond_to?(:extended), "Class already responds to extended")
    assert(! klass.new.respond_to?(:included), "Class already responds to included")


          assert_nothing_raised do sub.send(
        :initclass, klass,
        
      :include => incl, :extend => ext)
    end

    assert(klass.respond_to?(:extended), "Class did not get extended")
    assert(klass.new.respond_to?(:included), "Class did not include")
  end

  def test_genclass
    hash = {}
    array = []

    name = "yayness"
    klass = nil
    assert_nothing_raised {
      klass = GenTest.genclass(name, :array => array, :hash => hash, :parent => FakeBase) do
          class << self
            attr_accessor :name
          end
      end
    }

    assert(klass.respond_to?(:name=), "Class did not execute block")


          assert(
        hash.include?(klass.name),
        
      "Class did not get added to hash")

          assert(
        array.include?(klass),
        
      "Class did not get added to array")
    assert_equal(klass.superclass, FakeBase, "Parent class was wrong")
  end

  # Make sure we call a preinithook, if there is one.
  def test_inithooks
    newclass = Class.new(FakeBase) do
      class << self
        attr_accessor :preinited, :postinited
      end
      def self.preinit
        self.preinited = true
      end
      def self.postinit
        self.postinited = true
      end
    end

    klass = nil
    assert_nothing_raised {
      klass = GenTest.genclass(:funtest, :parent => newclass)
    }

    assert(klass.preinited, "prehook did not get called")
    assert(klass.postinited, "posthook did not get called")
  end

  def test_modulegen
    hash = {}
    array = []

    name = "modness"
    mod = nil
    assert_nothing_raised {
      mod = GenTest.genmodule(name, :array => array, :hash => hash) do
        class << self
          attr_accessor :yaytest
        end

        @yaytest = true
      end
    }

    assert(mod.respond_to?(:yaytest), "Class did not execute block")

    assert_instance_of(Module, mod)
    assert(hash.include?(mod.name), "Class did not get added to hash")
    assert(array.include?(mod), "Class did not get added to array")
  end

  def test_genconst_string
    const = nil
    assert_nothing_raised do
      const = GenTest.send(:genconst_string, :testing, :prefix => "Yayness")
    end
    assert_equal("YaynessTesting", const)
  end
end

