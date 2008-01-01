require File.dirname(__FILE__) + '/spec_helper'

module SharedBehaviourExample
  class OneThing
    def what_things_do
      "stuff"
    end
  end
  
  class AnotherThing
    def what_things_do
      "stuff"
    end
  end
  
  describe "All Things", :shared => true do
    def helper_method
      "helper method"
    end
    
    it "should do what things do" do
      @thing.what_things_do.should == "stuff"
    end
  end

  describe OneThing do
    it_should_behave_like "All Things"
    before(:each) { @thing = OneThing.new }
    
    it "should have access to helper methods defined in the shared behaviour" do
      helper_method.should == "helper method"
    end
  end

  describe AnotherThing do
    it_should_behave_like "All Things"
    before(:each) { @thing = AnotherThing.new }
  end
end
