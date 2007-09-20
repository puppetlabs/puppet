require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector do
  it "should provide a way to clear all registered classes" do
    Puppet::Indirector.should respond_to(:reset)
  end
  
  it "should provide a way to access a list of registered classes" do
    Puppet::Indirector.should respond_to(:indirections)
  end
end

describe Puppet::Indirector, "when no classes are registered" do
  before do
    Puppet::Indirector.reset
  end
  
  it "should provide an empty list of registered classes" do
    Puppet::Indirector.indirections.should == {}
  end  
end

describe Puppet::Indirector, " when included into a class" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
    end
  end

  it "should provide the indirects method to the class" do
    @thingie.should respond_to(:indirects)
  end
end

describe Puppet::Indirector, "when registering an indirection" do
  before do
    Puppet::Indirector.reset
    @thingie = Class.new do
      extend Puppet::Indirector
    end
    Puppet::Indirector.stubs(:terminus_for_indirection).returns(:ldap)
  end

  it "should require a name to register when indirecting" do
    Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
  end
  
  it "should require each indirection to be registered under a unique name" do
    @thingie.send(:indirects, :name)
    Proc.new {@thingie.send(:indirects, :name)}.should raise_error(ArgumentError)
  end
  
  it "should not allow a class to register multiple indirections" do
    @thingie.send(:indirects, :first)
    Proc.new {@thingie.send(:indirects, :second)}.should raise_error(ArgumentError)
  end
  
  it "should make a find method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:find)
  end
    
  it "should make a destroy method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:destroy)
  end
  
  it "should make a search method available on the registered class" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:search)
  end
  
  it "should make available the indirection used for a registered class" do
    mock_terminus = mock('Terminus')
    Puppet::Indirector.expects(:terminus_for_indirection).with(:node).returns(:ldap)
    Puppet::Indirector.expects(:terminus).returns(mock_terminus)
    @thingie.send(:indirects, :node)
    @thingie.indirection.should == mock_terminus
  end
  
  it "should make a save method available on instances of the registered class" do
    @thing = Class.new do
      extend Puppet::Indirector
      indirects :thing
    end.new
    @thing.should respond_to(:save)
  end
  
  it "should include the registered class in the list of all registered classes" do
    @thingie.send(:indirects, :name)
    Puppet::Indirector.indirections[:name].should == @thingie
  end  
  
  # when dealing with Terminus methods
  it "should look up the indirection configuration for the registered class when a new instance of that class is created" do
    Puppet::Indirector.expects(:terminus_for_indirection).with(:node).returns(:ldap)
    @thingie.send(:indirects, :node)
  end

  it "should use the Terminus described in the class configuration" do
    mock_terminus = mock('Terminus')
    Puppet::Indirector.expects(:terminus_for_indirection).with(:foo).returns(:bar)
    Puppet::Indirector.expects(:terminus).with(:foo, :bar).returns(mock_terminus)
    @thingie.send(:indirects, :foo)
  end
  
  it "should delegate to the Terminus find method when calling find on the registered class" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:find)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.find
  end

  it "should delegate to the Terminus destroy method when calling destroy on the registered class" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:destroy)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.destroy  
  end
  
  it "should delegate to the Terminus search method when calling search on the registered class" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:search)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.search    
  end
  
  it "should delegate to the Terminus save method when calling save on the registered class" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:save)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.new.save        
  end

  it "should allow a registered class to specify variations in behavior for a given Terminus"
end




describe Puppet::Indirector::Terminus do
  it "should register itself"  # ???
  
  it "should allow for finding an object from a collection"
  it "should allow for finding matching objects from a collection"
  it "should allow for destroying an object in a collection"
  it "should allow an object to be saved to a collection"
  it "should allow an object class to pre-process its arguments"
  it "should allow an object class to be in a read-only collection"
  
  it "should look up the appropriate decorator for the class"
  it "should call "
end


# describe Puppet::Indirector::Decorator do
#   it "should register itself"  # ???
# end




# describe Puppet::Indirector, " when managing indirections" do
#     before do
#         @indirector = Class.new
#         @indirector.send(:extend, Puppet::Indirector)
#     end
# 
#     it "should create an indirection" do
#         indirection = @indirector.indirects :test, :to => :node_source
#         indirection.name.should == :test
#         indirection.to.should == :node_source
#     end
# 
#     it "should not allow more than one indirection in the same object" do
#         @indirector.indirects :test
#         proc { @indirector.indirects :else }.should raise_error(ArgumentError)
#     end
# 
#     it "should allow multiple classes to use the same indirection" do
#         @indirector.indirects :test
#         other = Class.new
#         other.send(:extend, Puppet::Indirector)
#         proc { other.indirects :test }.should_not raise_error
#     end
# 
#     it "should should autoload termini from disk" do
#         Puppet::Indirector.expects(:instance_load).with(:test, "puppet/indirector/test")
#         @indirector.indirects :test
#     end
# 
#     after do
#         Puppet.config.clear
#     end
# end
# 
# describe Puppet::Indirector, " when performing indirections" do
#     before do
#         @indirector = Class.new
#         @indirector.send(:extend, Puppet::Indirector)
#         @indirector.indirects :test, :to => :node_source
# 
#         # Set up a fake terminus class that will just be used to spit out
#         # mock terminus objects.
#         @terminus_class = mock 'terminus_class'
#         Puppet::Indirector.stubs(:terminus).with(:test, :test_source).returns(@terminus_class)
#         Puppet[:node_source] = "test_source"
#     end
# 
#     it "should redirect http methods to the default terminus" do
#         terminus = mock 'terminus'
#         terminus.expects(:put).with("myargument")
#         @terminus_class.expects(:new).returns(terminus)
#         @indirector.put("myargument")
#     end
# end
