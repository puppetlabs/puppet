require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Mocks
    describe "A method stub" do
      before(:each) do
        @class = Class.new do
          def self.existing_class_method
            :original_value
          end

          def existing_instance_method
            :original_value
          end
        end
        @obj = @class.new
      end

      it "should allow for a mock expectation to temporarily replace a method stub on a mock" do
        mock = Spec::Mocks::Mock.new("a mock")
        mock.stub!(:msg).and_return(:stub_value)
        mock.should_receive(:msg).with(:arg).and_return(:mock_value)
        mock.msg(:arg).should equal(:mock_value)
        mock.msg.should equal(:stub_value)
        mock.msg.should equal(:stub_value)
        mock.rspec_verify
      end

      it "should allow for a mock expectation to temporarily replace a method stub on a non-mock" do
        @obj.stub!(:msg).and_return(:stub_value)
        @obj.should_receive(:msg).with(:arg).and_return(:mock_value)
        @obj.msg(:arg).should equal(:mock_value)
        @obj.msg.should equal(:stub_value)
        @obj.msg.should equal(:stub_value)
        @obj.rspec_verify
      end

      it "should ignore when expected message is not received" do
        @obj.stub!(:msg)
        lambda do
          @obj.rspec_verify
        end.should_not raise_error
      end
      
      it "should clear itself on rspec_verify" do
        @obj.stub!(:this_should_go).and_return(:blah)
        @obj.this_should_go.should == :blah
        @obj.rspec_verify
        lambda do
          @obj.this_should_go
        end.should raise_error
      end

      it "should ignore when expected message is received" do
        @obj.stub!(:msg)
        @obj.msg
        @obj.rspec_verify
      end

      it "should ignore when message is received with args" do
        @obj.stub!(:msg)
        @obj.msg(:an_arg)
        @obj.rspec_verify
      end

      it "should not support with" do
        lambda do
          Spec::Mocks::Mock.new("a mock").stub!(:msg).with(:arg)
        end.should raise_error(NoMethodError)
      end
      
      it "should return expected value when expected message is received" do
        @obj.stub!(:msg).and_return(:return_value)
        @obj.msg.should equal(:return_value)
        @obj.rspec_verify
      end

      it "should return values in order to consecutive calls" do
        return_values = ["1",2,Object.new]
        @obj.stub!(:msg).and_return(return_values[0],return_values[1],return_values[2])
        @obj.msg.should == return_values[0]
        @obj.msg.should == return_values[1]
        @obj.msg.should == return_values[2]
      end

      it "should keep returning last value in consecutive calls" do
        return_values = ["1",2,Object.new]
        @obj.stub!(:msg).and_return(return_values[0],return_values[1],return_values[2])
        @obj.msg.should == return_values[0]
        @obj.msg.should == return_values[1]
        @obj.msg.should == return_values[2]
        @obj.msg.should == return_values[2]
        @obj.msg.should == return_values[2]
      end

      it "should revert to original instance method if existed" do
        @obj.existing_instance_method.should equal(:original_value)
        @obj.stub!(:existing_instance_method).and_return(:mock_value)
        @obj.existing_instance_method.should equal(:mock_value)
        @obj.rspec_verify
        # TODO JRUBY: This causes JRuby to fail with:
        # NativeException in 'Stub should revert to original instance method if existed'
        # java.lang.ArrayIndexOutOfBoundsException: 0
        # org.jruby.internal.runtime.methods.IterateCallable.internalCall(IterateCallable.java:63)
        # org.jruby.internal.runtime.methods.AbstractCallable.call(AbstractCallable.java:64)
        # org.jruby.runtime.ThreadContext.yieldInternal(ThreadContext.java:574)
        # org.jruby.runtime.ThreadContext.yieldSpecificBlock(ThreadContext.java:549)
        # org.jruby.runtime.Block.call(Block.java:158)
        # org.jruby.RubyProc.call(RubyProc.java:118)
        # org.jruby.internal.runtime.methods.ProcMethod.internalCall(ProcMethod.java:69)
        # org.jruby.internal.runtime.methods.AbstractMethod.call(AbstractMethod.java:58)
        # org.jruby.RubyObject.callMethod(RubyObject.java:379)
        # org.jruby.RubyObject.callMethod(RubyObject.java:331)
        # org.jruby.evaluator.EvaluationState.evalInternal(EvaluationState.java:472)
        # org.jruby.evaluator.EvaluationState.evalInternal(EvaluationState.java:462)
        # org.jruby.evaluator.EvaluationState.evalInternal(EvaluationState.java:390)
        # org.jruby.evaluator.EvaluationState.eval(EvaluationState.java:133)
        @obj.existing_instance_method.should equal(:original_value)
      end
      
      it "should revert to original class method if existed" do
        @class.existing_class_method.should equal(:original_value)
        @class.stub!(:existing_class_method).and_return(:mock_value)
        @class.existing_class_method.should equal(:mock_value)
        @class.rspec_verify
        @class.existing_class_method.should equal(:original_value)
      end

      it "should clear itself on rspec_verify" do
        @obj.stub!(:this_should_go).and_return(:blah)
        @obj.this_should_go.should == :blah
        @obj.rspec_verify
        lambda do
          @obj.this_should_go
        end.should raise_error
      end
      
      it "should support yielding" do
        @obj.stub!(:method_that_yields).and_yield(:yielded_value)
        current_value = :value_before
        @obj.method_that_yields {|val| current_value = val}
        current_value.should == :yielded_value
        @obj.rspec_verify
      end

      it "should throw when told to" do
        @mock.stub!(:something).and_throw(:blech)
        lambda do
          @mock.something
        end.should throw_symbol(:blech)
      end
      
      it "should support overriding w/ a new stub" do
        @stub.stub!(:existing_instance_method).and_return(:updated_stub_value)
        @stub.existing_instance_method.should == :updated_stub_value
      end
    end
  end
end
