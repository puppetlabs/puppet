$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'rgen/util/method_delegation'

class MethodDelegationTest < Test::Unit::TestCase
  include RGen
  
  class TestDelegate
    attr_accessor :mode, :callcount
    def common_delegated(delegator)
      @callcount ||= 0
      @callcount += 1
      case @mode 
        when :continue
          throw :continue
        when :delegatorId
          delegator.object_id
        when :return7
          7
      end
    end
    alias to_s_delegated common_delegated
    alias methodInSingleton_delegated common_delegated
    alias class_delegated common_delegated
    alias artificialMethod_delegated common_delegated
  end
  
  class ConstPathElement < Module
    def self.const_missing_delegated(delegator, const)
      ConstPathElement.new(const)
    end
    def initialize(name, parent=nil)
      @name = name.to_s
      @parent = parent
    end
    def const_missing(const)
      ConstPathElement.new(const, self)
    end
    def to_s
      if @parent
        @parent.to_s+"::"+@name
      else
        @name
      end
    end
  end
  
  # missing: check with multiple params and block param
  
  def test_method_defined_in_singleton
    # delegator is an Array
    delegator = []
    # delegating method is a method defined in the singleton class
    class << delegator
      def methodInSingleton
        "result from method in singleton"
      end
    end
    checkDelegation(delegator, "methodInSingleton", "result from method in singleton")
  end
  
  def test_method_defined_in_class
    # delegator is a String
    delegator = "Delegator1"
    checkDelegation(delegator, "to_s", "Delegator1")
  end
  
  def test_method_defined_in_superclass
    # delegator is an instance of a new anonymous class
    delegator = Class.new.new
    # delegating method is +object_id+ which is defined in the superclass
    checkDelegation(delegator, "class", delegator.class)
  end
  
  def test_new_method
    # delegator is an String
    delegator = "Delegator2"
    # delegating method is a new method which does not exist on String
    checkDelegation(delegator, "artificialMethod", delegator.object_id, true)
  end
  
  def test_const_missing
    surroundingModule = Module.nesting.first
    Util::MethodDelegation.registerDelegate(ConstPathElement, surroundingModule, "const_missing")
    
    assert_equal "SomeArbitraryConst", SomeArbitraryConst.to_s
    assert_equal "AnotherConst::A::B::C", AnotherConst::A::B::C.to_s
    
    Util::MethodDelegation.unregisterDelegate(ConstPathElement, surroundingModule, "const_missing")
    assert_raise NameError do 
      SomeArbitraryConst
    end
  end
  
  def checkDelegation(delegator, method, originalResult, newMethod=false)
    delegate1 = TestDelegate.new
    delegate2 = TestDelegate.new
    
    Util::MethodDelegation.registerDelegate(delegate1, delegator, method)
    Util::MethodDelegation.registerDelegate(delegate2, delegator, method)
    
    assert delegator.respond_to?(:_methodDelegates)
    if newMethod
      assert !delegator.respond_to?("#{method}_delegate_original".to_sym)
    else
      assert delegator.respond_to?("#{method}_delegate_original".to_sym)
    end

    # check delegator parameter    
    delegate1.mode = :delegatorId
    assert_equal delegator.object_id, delegator.send(method)
    
    delegate1.callcount = 0
    delegate2.callcount = 0
    
    delegate1.mode = :return7
    # delegate1 returns a value
    assert_equal 7, delegator.send(method)
    assert_equal 1, delegate1.callcount
    # delegate2 is not called
    assert_equal 0, delegate2.callcount
    
    delegate1.mode = :nothing
    # delegate1 just exits and thus returns nil
    assert_equal nil, delegator.send(method)
    assert_equal 2, delegate1.callcount
    # delegate2 is not called
    assert_equal 0, delegate2.callcount
    
    delegate1.mode = :continue
    delegate2.mode = :return7
    # delegate1 is called but continues
    # delegate2 returns a value
    assert_equal 7, delegator.send(method)
    assert_equal 3, delegate1.callcount
    assert_equal 1, delegate2.callcount
    
    delegate1.mode = :continue
    delegate2.mode = :continue
    # both delegates continue, the original method returns its value
    checkCallOriginal(delegator, method, originalResult, newMethod)
    # both delegates are called though
    assert_equal 4, delegate1.callcount
    assert_equal 2, delegate2.callcount
    
    # calling unregister with a non existing method has no effect
    Util::MethodDelegation.unregisterDelegate(delegate1, delegator, "xxx")
    Util::MethodDelegation.unregisterDelegate(delegate1, delegator, method)
    
    checkCallOriginal(delegator, method, originalResult, newMethod)
    # delegate1 not called any more
    assert_equal 4, delegate1.callcount
    # delegate2 is still called
    assert_equal 3, delegate2.callcount
    
    Util::MethodDelegation.unregisterDelegate(delegate2, delegator, method)
    
    checkCallOriginal(delegator, method, originalResult, newMethod)
    # both delegates not called any more
    assert_equal 4, delegate1.callcount
    assert_equal 3, delegate2.callcount
    
    # after all delegates were unregistered, singleton class should be clean
    assert !delegator.respond_to?(:_methodDelegates)
  end  
  
  def checkCallOriginal(delegator, method, originalResult, newMethod)
    if newMethod
      assert_raise NoMethodError do
        result = delegator.send(method)
      end
    else
      result = delegator.send(method)
      assert_equal originalResult, result
    end
  end
end
