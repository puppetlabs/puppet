require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module Mocks
    describe "a Mock expectation" do

      before do
        @mock = mock("test mock")
      end
      
      after do
        @mock.rspec_reset
      end
      
      it "should report line number of expectation of unreceived message" do
        @mock.should_receive(:wont_happen).with("x", 3)
        #NOTE - this test is quite ticklish because it specifies that
        #the above statement appears on line 12 of this file.

        begin
          @mock.rspec_verify
          violated
        rescue MockExpectationError => e
          e.backtrace[0].should match(/mock_spec\.rb:16/)
        end
    
      end
      
      it "should pass when not receiving message specified as not to be received" do
        @mock.should_not_receive(:not_expected)
        @mock.rspec_verify
      end

      it "should pass when receiving message specified as not to be received with different args" do
        @mock.should_not_receive(:message).with("unwanted text")
        @mock.should_receive(:message).with("other text")
        @mock.message "other text"
        @mock.rspec_verify
      end

      it "should fail when receiving message specified as not to be received" do
        @mock.should_not_receive(:not_expected)
        @mock.not_expected
        begin
          @mock.rspec_verify
          violated
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :not_expected with (any args) 0 times, but received it once"
        end
      end

      it "should fail when receiving message specified as not to be received with args" do
        @mock.should_not_receive(:not_expected).with("unexpected text")
        @mock.not_expected("unexpected text")
        begin
          @mock.rspec_verify
          violated
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :not_expected with (\"unexpected text\") 0 times, but received it once"
        end
      end

      it "should pass when receiving message specified as not to be received with wrong args" do
        @mock.should_not_receive(:not_expected).with("unexpected text")
        @mock.not_expected "really unexpected text"
        @mock.rspec_verify
      end

      it "should allow block to calculate return values" do
        @mock.should_receive(:something).with("a","b","c").and_return { |a,b,c| c+b+a }
        @mock.something("a","b","c").should == "cba"
        @mock.rspec_verify
      end

      it "should allow parameter as return value" do
        @mock.should_receive(:something).with("a","b","c").and_return("booh")
        @mock.something("a","b","c").should == "booh"
        @mock.rspec_verify
      end

      it "should return nil if no return value set" do
        @mock.should_receive(:something).with("a","b","c")
        @mock.something("a","b","c").should be_nil
        @mock.rspec_verify
      end

      it "should raise exception if args dont match when method called" do
        @mock.should_receive(:something).with("a","b","c").and_return("booh")
        begin
          @mock.something("a","d","c")
          violated
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :something with (\"a\", \"b\", \"c\") but received it with (\"a\", \"d\", \"c\")"
        end
      end
     
      it "should fail if unexpected method called" do
        begin
          @mock.something("a","b","c")
          violated
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' received unexpected message :something with (\"a\", \"b\", \"c\")"
        end
      end
  
      it "should use block for expectation if provided" do
        @mock.should_receive(:something) do | a, b |
          a.should == "a"
          b.should == "b"
          "booh"
        end
        @mock.something("a", "b").should == "booh"
        @mock.rspec_verify
      end
  
      it "should fail if expectation block fails" do
        @mock.should_receive(:something) {| bool | bool.should be_true}
        begin
          @mock.something false
        rescue MockExpectationError => e
          e.message.should match(/Mock 'test mock' received :something but passed block failed with: expected true, got false/)
        end
      end
  
      it "should fail when method defined as never is received" do
        @mock.should_receive(:not_expected).never
        begin
          @mock.not_expected
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :not_expected 0 times, but received it 1 times"
        end
      end
      
      it "should raise when told to" do
        @mock.should_receive(:something).and_raise(RuntimeError)
        lambda do
          @mock.something
        end.should raise_error(RuntimeError)
      end
 
      it "should raise passed an Exception instance" do
        error = RuntimeError.new("error message")
        @mock.should_receive(:something).and_raise(error)
        begin
          @mock.something
        rescue RuntimeError => e
          e.message.should eql("error message")
        end
      end

      it "should raise RuntimeError with passed message" do
        @mock.should_receive(:something).and_raise("error message")
        begin
          @mock.something
        rescue RuntimeError => e
          e.message.should eql("error message")
        end
      end
 
      it "should not raise when told to if args dont match" do
        @mock.should_receive(:something).with(2).and_raise(RuntimeError)
        lambda do
          @mock.something 1
        end.should raise_error(MockExpectationError)
      end
 
      it "should throw when told to" do
        @mock.should_receive(:something).and_throw(:blech)
        lambda do
          @mock.something
        end.should throw_symbol(:blech)
      end

      it "should raise when explicit return and block constrained" do
        lambda do
          @mock.should_receive(:fruit) do |colour|
            :strawberry
          end.and_return :apple
        end.should raise_error(AmbiguousReturnError)
      end
      
      it "should ignore args on any args" do
        @mock.should_receive(:something).at_least(:once).with(any_args)
        @mock.something
        @mock.something 1
        @mock.something "a", 2
        @mock.something [], {}, "joe", 7
        @mock.rspec_verify
      end
      
      it "should fail on no args if any args received" do
        @mock.should_receive(:something).with(no_args())
        begin
          @mock.something 1
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :something with (no args) but received it with (1)"
        end
      end
      
      it "should fail when args are expected but none are received" do
        @mock.should_receive(:something).with(1)
        begin
          @mock.something
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' expected :something with (1) but received it with (no args)"
        end
      end

      it "should yield 0 args to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield
        a = nil
        @mock.yield_back {|*a|}
        a.should == []
        @mock.rspec_verify
      end

      it "should yield one arg to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99)
        a = nil
        @mock.yield_back {|*a|}
        a.should == [99]
        @mock.rspec_verify
      end

      it "should yield many args to blocks that take a variable number of arguments" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99, 27, "go")
        a = nil
        @mock.yield_back {|*a|}
        a.should == [99, 27, "go"]
        @mock.rspec_verify
      end

      it "should yield single value" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield(99)
        a = nil
        @mock.yield_back {|a|}
        a.should == 99
        @mock.rspec_verify
      end

      it "should yield two values" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
        a, b = nil
        @mock.yield_back {|a,b|}
        a.should == 'wha'
        b.should == 'zup'
        @mock.rspec_verify
      end

      it "should fail when calling yielding method with wrong arity" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
          begin
          @mock.yield_back {|a|}
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' yielded |\"wha\", \"zup\"| to block with arity of 1"
        end
      end

      it "should fail when calling yielding method without block" do
        @mock.should_receive(:yield_back).with(no_args()).once.and_yield('wha', 'zup')
        begin
          @mock.yield_back
        rescue MockExpectationError => e
          e.message.should == "Mock 'test mock' asked to yield |\"wha\", \"zup\"| but no block was passed"
        end
      end
      
      it "should be able to mock send" do
        @mock.should_receive(:send).with(any_args)
        @mock.send 'hi'
        @mock.rspec_verify
      end
      
      it "should be able to raise from method calling yielding mock" do
        @mock.should_receive(:yield_me).and_yield 44
        
        lambda do
          @mock.yield_me do |x|
            raise "Bang"
          end
        end.should raise_error(StandardError)

        @mock.rspec_verify
      end
      
      # TODO - this is failing, but not if you run the file w/ --reverse - weird!!!!!!
      # specify "should clear expectations after verify" do
      #   @mock.should_receive(:foobar)
      #   @mock.foobar
      #   @mock.rspec_verify
      #   begin
      #     @mock.foobar
      #   rescue MockExpectationError => e
      #     e.message.should == "Mock 'test mock' received unexpected message :foobar with (no args)"
      #   end
      # end
      
      it "should restore objects to their original state on rspec_reset" do
        mock = mock("this is a mock")
        mock.should_receive(:blah)
        mock.rspec_reset
        mock.rspec_verify #should throw if reset didn't work
      end

    end

    describe "a mock message receiving a block" do
      before(:each) do
        @mock = mock("mock")
        @calls = 0
      end
      
      def add_call
        @calls = @calls + 1
      end
      
      it "should call the block after #should_receive" do
        @mock.should_receive(:foo) { add_call }

        @mock.foo

        @calls.should == 1
      end

      it "should call the block after #once" do
        @mock.should_receive(:foo).once { add_call }

        @mock.foo

        @calls.should == 1
      end

      it "should call the block after #twice" do
        @mock.should_receive(:foo).twice { add_call }

        @mock.foo
        @mock.foo

        @calls.should == 2
      end

      it "should call the block after #times" do
        @mock.should_receive(:foo).exactly(10).times { add_call }
        
        (1..10).each { @mock.foo }

        @calls.should == 10
      end

      it "should call the block after #any_number_of_times" do
        @mock.should_receive(:foo).any_number_of_times { add_call }
        
        (1..7).each { @mock.foo }

        @calls.should == 7
      end

      it "should call the block after #with" do
        @mock.should_receive(:foo).with(:arg) { add_call }
        
        @mock.foo(:arg)

        @calls.should == 1
      end

      it "should call the block after #ordered" do
        @mock.should_receive(:foo).ordered { add_call }
        @mock.should_receive(:bar).ordered { add_call }
        
        @mock.foo
        @mock.bar

        @calls.should == 2
      end
    end
  end
end
