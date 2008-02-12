require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module DSL
    describe BehaviourEval do
      def count
        @count ||= 0
        @count = @count + 1
        @count
      end

      before(:all) do
        count.should == 1
      end

      before(:all) do
        count.should == 2
      end

      before(:each) do
        count.should == 3
      end

      before(:each) do
        count.should == 4
      end

      it "should run before(:all), before(:each), example, after(:each), after(:all) in order" do
        count.should == 5
      end

      after(:each) do
        count.should == 7
      end

      after(:each) do
        count.should == 6
      end

      after(:all) do
        count.should == 9
      end

      after(:all) do
        count.should == 8
      end
    end
    
    describe BehaviourEval, "instance methods" do
      it "should support pending" do
        lambda {
          pending("something")
        }.should raise_error(Spec::DSL::ExamplePendingError, "something")
      end

      it "should have #pending raise a Pending error when its block fails" do
        block_ran = false
        lambda {
          pending("something") do
            block_ran = true
            raise "something wrong with my example"
          end
        }.should raise_error(Spec::DSL::ExamplePendingError, "something")
        block_ran.should == true
      end

      it "should have #pending raise Spec::DSL::PendingFixedError when its block does not fail" do
        block_ran = false
        lambda {
          pending("something") do
            block_ran = true
          end
        }.should raise_error(Spec::DSL::PendingFixedError, "Expected pending 'something' to fail. No Error was raised.")
        block_ran.should == true
      end

    end
  end
end
