require File.dirname(__FILE__) + '/../../spec_helper'

module Spec
  module DSL
    describe CompositeProcBuilder do
      before(:each) do
        @klass = Class.new do
          attr_reader :an_attribute

          def an_attribute_setter
            @an_attribute = :the_value
          end
        end

        @parent = @klass.new
        @builder = CompositeProcBuilder.new {}
      end

      it "calls all of its child procs" do
        @builder << proc {:proc1}
        @builder << proc {:proc2}
        @builder.proc.call.should == [:proc1, :proc2]
      end

      it "evals procs in the caller's instance" do
        the_proc = proc do
          @an_attribute = :the_value
        end
        the_proc.class.should == Proc
        @builder << the_proc
        @parent.instance_eval &@builder.proc
        @parent.an_attribute.should == :the_value
      end

      it "binds unbound methods to the parent" do
        unbound_method = @klass.instance_method(:an_attribute_setter)
        unbound_method.class.should == UnboundMethod
        @builder << unbound_method
        @parent.instance_eval &@builder.proc
        @parent.an_attribute.should == :the_value
      end
    end
  end
end
