require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector do
  it "should provide a way to clear all registrations" do
    Puppet::Indirector.should respond_to(:reset)
  end
  
  it "should provide a way to access a list of all registered models" do
    Puppet::Indirector.should respond_to(:indirections)
  end
end

describe Puppet::Indirector, "when no models are registered" do
  before do
    Puppet::Indirector.reset
  end
  
  it "should provide an empty list of registered models" do
    Puppet::Indirector.indirections.should == {}
  end  
end

describe Puppet::Indirector, " when available to a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
    end
  end

  it "should provide a way for the model to register an indirection under a name" do
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

  it "should require a name when registering a model" do
    Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
  end
  
  it "should require each model to be registered under a unique name" do
    @thingie.send(:indirects, :name)
    Proc.new {@thingie.send(:indirects, :name)}.should raise_error(ArgumentError)
  end
  
  it "should not allow a model to register under multiple names" do
    @thingie.send(:indirects, :first)
    Proc.new {@thingie.send(:indirects, :second)}.should raise_error(ArgumentError)
  end
  
  it "should allow finding an instance of a model in a collection" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:find)
  end
    
  it "should allow removing an instance of a model from a collection" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:destroy)
  end
  
  it "should allow finding all matching model instances in a collection" do
    @thingie.send(:indirects, :first)
    @thingie.should respond_to(:search)
  end
  
  it "should allow for storing a model instance in a collection" do
    @thing = Class.new do
      extend Puppet::Indirector
      indirects :thing
    end.new
    @thing.should respond_to(:save)
  end
    
  it "should provide a way to get a handle to the terminus for a model" do
    mock_terminus = mock('Terminus')
    Puppet::Indirector.expects(:terminus_for_indirection).with(:node).returns(:ldap)
    Puppet::Indirector.expects(:terminus).returns(mock_terminus)
    @thingie.send(:indirects, :node)
    @thingie.indirection.should == mock_terminus
  end
  
  it "should list the model in a list of known indirections" do
    @thingie.send(:indirects, :name)
    Puppet::Indirector.indirections[:name].should == @thingie
  end  
  
  # when dealing with Terminus methods
  it "should consult a per-model configuration to determine what kind of collection a model is being stored in" do
    Puppet::Indirector.expects(:terminus_for_indirection).with(:node).returns(:ldap)
    @thingie.send(:indirects, :node)
  end

  it "should use the collection type described in the per-model configuration" do
    mock_terminus = mock('Terminus')
    Puppet::Indirector.expects(:terminus_for_indirection).with(:foo).returns(:bar)
    Puppet::Indirector.expects(:terminus).with(:foo, :bar).returns(mock_terminus)
    @thingie.send(:indirects, :foo)
  end
  
  it "should handle lookups of a model instance by letting the terminus perform the lookup" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:find)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.find
  end

  it "should handle removing model instances from a collection letting the terminus remove the instance" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:destroy)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.destroy  
  end
  
  it "should handle searching for model instances by letting the terminus find the matching instances" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:search)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.search    
  end
  
  it "should handle storing a model instance by letting the terminus store the instance" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:save)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.new.save        
  end
  
  it "should provide the same terminus for a given registered model"

  it "should not access the collection for a registered model until that collection is actually needed"

# TODO:  node lookup retries/searching
end




# describe Puppet::Indirector::Terminus do
#   it "should register itself"  # ???
#   
#   it "should allow for finding an object from a collection"
#   it "should allow for finding matching objects from a collection"
#   it "should allow for destroying an object in a collection"
#   it "should allow an object to be saved to a collection"
#   it "should allow an object class to pre-process its arguments"
#   it "should allow an object class to be in a read-only collection"
#   
#   it "should look up the appropriate decorator for the class"
#   it "should call "
# end
