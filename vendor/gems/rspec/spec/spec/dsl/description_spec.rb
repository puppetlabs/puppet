require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module DSL
    describe Description, " constructed with a single String" do 
      before(:each) {@description = Description.new("abc")}
      
      it "should provide that string as its name" do
        @description.description.should == "abc"
      end
      it "should provide nil as its type" do
        @description.described_type.should be_nil
      end
      it "should respond to []" do
        @description[:key].should be_nil
      end
      it "should respond to []=" do
        @description[:key] = :value
        @description[:key].should == :value
      end
      it "should return for == when value matches description" do
        @description.should == "abc"
      end
      it "should return for == when value is other description that matches description" do
        @description.should == Description.new("abc")
      end
    end
    
    describe Description, " constructed with a Type" do 
      before(:each) {@description = Description.new(Behaviour)}

      it "should provide a String representation of that type (fully qualified) as its name" do
        @description.description.should == "Spec::DSL::Behaviour"
      end
      it "should provide that type (fully qualified) as its type" do
        @description.described_type.should == Spec::DSL::Behaviour
      end
    end
    
    describe Description, " constructed with a Type and a String" do 
      before(:each) {@description = Description.new(Behaviour, " behaving")}
      
      it "should include the type and second String in its name" do
        @description.description.should == "Spec::DSL::Behaviour behaving"
      end
      it "should provide that type (fully qualified) as its type" do
        @description.described_type.should == Spec::DSL::Behaviour
      end
    end

    describe Description, "constructed with a Type and a String not starting with a space" do 
      before(:each) {@description = Description.new(Behaviour, "behaving")}

      it "should include the type and second String with a space in its name" do
        @description.description.should == "Spec::DSL::Behaviour behaving"
      end
    end

    describe Description, "constructed with a Type and a String starting with a ." do 
      before(:each) {@description = Description.new(Behaviour, ".behaving")}

      it "should include the type and second String with a space in its name" do
        @description.description.should == "Spec::DSL::Behaviour.behaving"
      end
    end

    describe Description, "constructed with a Type and a String starting with a #" do 
      before(:each) {@description = Description.new(Behaviour, "#behaving")}

      it "should include the type and second String with a space in its name" do
        @description.description.should == "Spec::DSL::Behaviour#behaving"
      end
    end

    describe Description, " constructed with options" do
      before(:each) do
        @description = Description.new(Behaviour, :a => "b", :spec_path => "blah")
      end

      it "should provide its options" do
        @description[:a].should == "b"
      end
      
      it "should wrap spec path using File.expand_path" do
        @description[:spec_path].should == File.expand_path("blah")
      end
    end
  end
end
