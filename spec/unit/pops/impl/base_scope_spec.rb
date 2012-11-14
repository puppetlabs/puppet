require 'spec_helper'
require 'puppet/pops/impl/base_scope'

BaseScope = Puppet::Pops::Impl::BaseScope

describe Puppet::Pops::Impl::BaseScope do

  describe "An instance of BaseScope" do
    # smoke test
    it "should not crash when created" do
      scope = BaseScope.new
      scope.is_a?(BaseScope).should == true
    end

    it "should respond to all API methods" do
      api_methods = Puppet::Pops::API::Scope.instance_methods(false)
      scope = BaseScope.new
      api_methods.each {|m| scope.respond_to?(m).should == true }
    end
    
    it "should be possible to store and retrieve a variable" do
      scope = BaseScope.new
      scope.set_variable('foo', 1)
      entry = scope.get_variable_entry('foo')
      entry.value.should == 1
      scope['foo'].value.should == 1
    end
    
    it "should be possible to reference numeric match variables (in numeric and string form) when no match has been set" do
      scope = BaseScope.new
      entry = scope.get_variable_entry('0')
      entry.should_not == nil
      entry.value.should == nil
      scope['0'].value().should == nil
      scope[0].value().should == nil      
    end
    
    it "should be possible to reference numeric match variables (in numeric and string form) when match has been set" do
      scope = BaseScope.new
      scope.set_match_data(/(monkey) (see), (monkey) (do)/.match("monkey see, monkey do"))
      scope['0'].value.should == "monkey see, monkey do" 
      scope[0].value.should == "monkey see, monkey do" 
      scope[1].value.should == "monkey" 
      scope[4].value.should == "do"
      scope['4'].value.should == "do"
      scope.get_variable_entry(4).value().should == "do" 
      scope.get_variable_entry('4').value().should == "do" 
    end
    
    it "should clear match variables when setting no match data" do
      scope = BaseScope.new
      scope.set_match_data(/(monkey) (see), (monkey) (do)/.match("monkey see, monkey do"))
      scope[0].value.should == "monkey see, monkey do"
      scope.set_match_data(nil) 
      scope[0].value.should_not == "monkey see, monkey do"
    end
    
    it "should be possible to store and retrieve data of different types" do
      scope = BaseScope.new
      scope.set_data(:file, '/some/file/name', 1)
      entry = scope.get_data_entry(:file, '/some/file/name')
      entry.value.should == 1
      scope[:file, '/some/file/name'].value.should == 1
    end
    
    it "should separate names per type" do
      scope = BaseScope.new
      scope.set_data(:file, 'a', 1)
      scope.set_data(:package, 'a', 2)
      scope[:file, 'a'].value.should == 1
      scope[:package, 'a'].value.should == 2
    end

    it "should protect immutable data entries" do
      scope = BaseScope.new
      scope.set_data(:file, 'a', 1)
      expect { scope.set_data(:file, 'a', 2) }.to raise_error(Puppet::Pops::API::ImmutableError)
      scope[:file, 'a'].value.should == 1
    end
    
    it "should protect immutable variable entries" do
      scope = BaseScope.new
      scope.set_variable('a', 1)
      expect { scope.set_variable('a', 2) }.to raise_error(Puppet::Pops::API::ImmutableError)
      scope['a'].value.should == 1
    end

    it "should not pretend to be a specific kind of scope" do
      scope = BaseScope.new
      scope.is_named_scope?().should == false
      scope.is_top_scope?().should == false
      scope.is_local_scope?().should == false
    end
    
  end
end