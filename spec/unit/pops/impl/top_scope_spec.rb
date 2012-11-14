require 'spec_helper'
require 'puppet/pops/impl/top_scope'

#BaseScope = Puppet::Pops::Impl::BaseScope
TopScope = Puppet::Pops::Impl::TopScope

# TODO: These tests only test the difference from BaseScope, could test the API
describe Puppet::Pops::Impl::TopScope do

  describe "An instance of TopScope" do
    # smoke test
    # Assumptions made that BaseScope is tested
    it "should be a BaseScope" do
      scope = TopScope.new
      scope.is_a?(TopScope).should == true
      scope.kind_of?(BaseScope).should == true
    end

    it "should respond to all API methods" do
      api_methods = Puppet::Pops::API::Scope.instance_methods(false)
      scope = TopScope.new
      api_methods.each {|m| scope.respond_to?(m).should == true }
    end
    
    it "should present itself as a top scope" do
      scope = TopScope.new
      scope.is_named_scope?().should == false
      scope.is_top_scope?().should == true
      scope.is_local_scope?().should == false
    end
    
    it "should contain a type creator" do
      scope = TopScope.new
      scope.type_creator.class.should == Pops::Impl::TypeCreator
    end
  end
end