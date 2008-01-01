require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Behaviour do

      before(:each) do
        @formatter = Spec::Mocks::Mock.new("formatter")
        @behaviour = Behaviour.new("behaviour") {}
      end

      it "should retain examples that don't match" do
        @behaviour.it("example1") {}
        @behaviour.it("example2") {}
        @behaviour.retain_examples_matching!(["behaviour"])
        @behaviour.number_of_examples.should == 2
      end

      it "should remove examples that match" do
        @behaviour.it("example1") {}
        @behaviour.it("example2") {}
        @behaviour.retain_examples_matching!(["behaviour example1"])
        @behaviour.number_of_examples.should == 1
      end
    end
  end
end
