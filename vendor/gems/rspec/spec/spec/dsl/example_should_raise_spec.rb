require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Example, " declared with {:should_raise => ...}" do
      before(:each) do
        @reporter = mock("reporter")
        @reporter.stub!(:example_started)
      end
  
      def verify_error(error, message=nil)
        error.should be_an_instance_of(Spec::Expectations::ExpectationNotMetError)
        unless message.nil?
          return error.message.should =~ message if Regexp === message
          return error.message.should == message
        end
      end

      it "true} should pass when there is an ExpectationNotMetError" do
        example = Spec::DSL:: Example.new("example", :should_raise => true) do
          raise Spec::Expectations::ExpectationNotMetError
        end
        @reporter.should_receive(:example_finished) do |description, error|
          error.should be_nil
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "true} should fail if nothing is raised" do
        example = Spec::DSL:: Example.new("example", :should_raise => true) {}
        @reporter.should_receive(:example_finished) do |example_name, error|
          verify_error(error, /example block expected Exception but nothing was raised/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "NameError} should pass when there is a NameError" do
        example = Spec::DSL:: Example.new("example", :should_raise => NameError) do
          raise NameError
        end
        @reporter.should_receive(:example_finished) do |example_name, error|
          error.should be_nil
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "NameError} should fail when there is no error" do
        example = Spec::DSL:: Example.new("example", :should_raise => NameError) do
          #do nothing
        end
        @reporter.should_receive(:example_finished) do |example_name, error|
          verify_error(error,/example block expected NameError but nothing was raised/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "NameError} should fail when there is the wrong error" do
        example = Spec::DSL:: Example.new("example", :should_raise => NameError) do
          raise RuntimeError
        end
        @reporter.should_receive(:example_finished) do |example_name, error|
          verify_error(error, /example block expected NameError but raised.+RuntimeError/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError]} should pass when there is a NameError" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError]) do
          raise NameError
        end
        @reporter.should_receive(:example_finished) do |description, error|
          error.should be_nil
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError]} should fail when there is no error" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError]) do
        end
        @reporter.should_receive(:example_finished) do |description, error|
          verify_error(error, /example block expected NameError but nothing was raised/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError]} should fail when there is the wrong error" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError]) do
          raise RuntimeError
        end
        @reporter.should_receive(:example_finished) do |description, error|
          verify_error(error, /example block expected NameError but raised.+RuntimeError/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError, 'message'} should pass when there is a NameError with the right message" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError, 'expected']) do
          raise NameError, 'expected'
        end
        @reporter.should_receive(:example_finished) do |description, error|
          error.should be_nil
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError, 'message'} should pass when there is a NameError with a message matching a regex" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError, /xpec/]) do
          raise NameError, 'expected'
        end
        @reporter.should_receive(:example_finished) do |description, error|
          error.should be_nil
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError, 'message'} should fail when there is a NameError with the wrong message" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError, 'expected']) do
          raise NameError, 'wrong message'
        end
        @reporter.should_receive(:example_finished) do |description, error|
          verify_error(error, /example block expected #<NameError: expected> but raised #<NameError: wrong message>/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end

      it "[NameError, 'message'} should fail when there is a NameError with a message not matching regexp" do
        example = Spec::DSL:: Example.new("spec", :should_raise => [NameError, /exp/]) do
          raise NameError, 'wrong message'
        end
        @reporter.should_receive(:example_finished) do |description, error|
          verify_error(error, /example block expected #<NameError: \(\?-mix:exp\)> but raised #<NameError: wrong message>/)
        end
        example.run(@reporter, nil, nil, nil, nil)
      end
    end
  end
end
