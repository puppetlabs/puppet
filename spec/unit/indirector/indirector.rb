require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, " when available to a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
    end
  end

  it "should provide a way for the model to register an indirection under a name" do
    @thingie.should respond_to(:indirects)
  end
  
  it "should give model the ability to lookup a model instance by letting the indirection perform the lookup" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:find)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.find
  end

  it "should give model the ability to remove model instances from a terminus by letting the indirection remove the instance" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:destroy)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.destroy  
  end
  
  it "should give model the ability to search for model instances by letting the indirection find the matching instances" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:search)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.search    
  end
  
  it "should give model the ability to store a model instance by letting the indirection store the instance" do
    @thingie.send(:indirects, :node)
    mock_terminus = mock('Terminus')
    mock_terminus.expects(:save)
    @thingie.expects(:indirection).returns(mock_terminus)
    @thingie.new.save        
  end
end

describe Puppet::Indirector, "when registering an indirection" do
  before do
    Puppet::Indirector.reset
    @thingie = Class.new do
      extend Puppet::Indirector
    end
    Puppet::Indirector.stubs(:terminus_for_indirection).returns(:ldap)
    @terminus = mock 'terminus'
    @terminus_class = stub 'terminus class', :new => @terminus
    Puppet::Indirector.stubs(:terminus).returns(@terminus_class)
  end

  it "should require a name when registering a model" do
    Proc.new {@thingie.send(:indirects) }.should raise_error(ArgumentError)
  end
    
    it "should not allow a model to register under multiple names" do
        @thingie.send(:indirects, :first)
        Proc.new {@thingie.send(:indirects, :second)}.should raise_error(ArgumentError)
    end

    it "should create an indirection instance to manage each indirecting model"

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
