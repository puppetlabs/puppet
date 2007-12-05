require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe BehaviourRunner, "#add_behaviour affecting passed in behaviour" do
      before do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err,@out)
        @runner = BehaviourRunner.new(@options)
        class << @runner
          attr_reader :behaviours
        end

        @behaviour = ::Spec::DSL::Behaviour.new("A Behaviour") do
          it "runs 1" do
          end
          it "runs 2" do
          end
        end
      end
      
      it "removes examples not selected from Behaviour when options.examples is set" do
        @options.examples << "A Behaviour runs 1"

        @behaviour.number_of_examples.should == 2

        @runner.add_behaviour @behaviour
        @behaviour.number_of_examples.should == 1
        @behaviour.examples.first.send(:description).should == "runs 1"
      end

      it "keeps all examples when options.examples is nil" do
        @options.examples = nil
        @behaviour.number_of_examples.should == 2

        @runner.add_behaviour @behaviour
        @behaviour.number_of_examples.should == 2
        @behaviour.examples.collect {|example| example.send(:description) }.should == ['runs 1', 'runs 2']
      end

      it "keeps all examples when options.examples is empty" do
        @options.examples = []
        @behaviour.number_of_examples.should == 2

        @runner.add_behaviour @behaviour
        @behaviour.number_of_examples.should == 2
        @behaviour.examples.collect {|example| example.send(:description) }.should == ['runs 1', 'runs 2']
      end
    end

    describe BehaviourRunner, "#add_behaviour affecting behaviours" do
      before do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err,@out)
        @runner = BehaviourRunner.new(@options)
        class << @runner
          attr_reader :behaviours
        end
      end

      it "adds behaviour when behaviour has examples and is not shared" do
        @behaviour = ::Spec::DSL::Behaviour.new("A Behaviour") do
          it "uses this behaviour" do
          end
        end

        @behaviour.should_not be_shared
        @behaviour.number_of_examples.should be > 0
        @runner.add_behaviour @behaviour

        @runner.behaviours.length.should == 1
      end

      it "does not add the behaviour when number_of_examples is 0" do
        @behaviour = ::Spec::DSL::Behaviour.new("A Behaviour") do
        end
        @behaviour.number_of_examples.should == 0
        @runner.add_behaviour @behaviour

        @runner.behaviours.should be_empty
      end

      it "does not add the behaviour when behaviour is shared" do
        @behaviour = ::Spec::DSL::Behaviour.new("A Behaviour", :shared => true) do
          it "does not use this behaviour" do
          end
        end
        @behaviour.should be_shared
        @runner.add_behaviour @behaviour

        @runner.behaviours.should be_empty
      end
    end

    describe BehaviourRunner do
      before do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err,@out)
      end

      it "should only run behaviours with at least one example" do
        desired_behaviour = mock("desired behaviour")
        desired_behaviour.should_receive(:run)
        desired_behaviour.should_receive(:retain_examples_matching!)
        desired_behaviour.should_receive(:number_of_examples).twice.and_return(1)
        desired_behaviour.should_receive(:shared?).and_return(false)
        desired_behaviour.should_receive(:set_sequence_numbers).with(0, anything)

        other_behaviour = mock("other behaviour")
        other_behaviour.should_receive(:run).never
        other_behaviour.should_receive(:retain_examples_matching!)
        other_behaviour.should_receive(:number_of_examples).and_return(0)

        reporter = mock("reporter")
        @options.reporter = reporter
        @options.examples = ["desired behaviour legal spec"]

        runner = Spec::Runner::BehaviourRunner.new(@options)
        runner.add_behaviour(desired_behaviour)
        runner.add_behaviour(other_behaviour)
        reporter.should_receive(:start)
        reporter.should_receive(:end)
        reporter.should_receive(:dump)
        runner.run([], false)
      end

      it "should dump even if Interrupt exception is occurred" do
        behaviour = Spec::DSL::Behaviour.new("behaviour") do
          it "no error" do
          end

          it "should interrupt" do
            raise Interrupt
          end
        end
        
        reporter = mock("reporter")
        reporter.should_receive(:start)
        reporter.should_receive(:add_behaviour)
        reporter.should_receive(:example_started).twice
        reporter.should_receive(:example_finished).twice
        reporter.should_receive(:rspec_verify)
        reporter.should_receive(:rspec_reset)
        reporter.should_receive(:end)
        reporter.should_receive(:dump)

        @options.reporter = reporter
        runner = Spec::Runner::BehaviourRunner.new(@options)
        runner.add_behaviour(behaviour)
        runner.run([], false)
      end

      it "should heckle when options have heckle_runner" do
        behaviour = mock("behaviour", :null_object => true)
        behaviour.should_receive(:number_of_examples).twice.and_return(1)
        behaviour.should_receive(:run).and_return(0)
        behaviour.should_receive(:shared?).and_return(false)

        reporter = mock("reporter")
        reporter.should_receive(:start).with(1)
        reporter.should_receive(:end)
        reporter.should_receive(:dump).and_return(0)

        heckle_runner = mock("heckle_runner")
        heckle_runner.should_receive(:heckle_with)

        @options.reporter = reporter
        @options.heckle_runner = heckle_runner

        runner = Spec::Runner::BehaviourRunner.new(@options)
        runner.add_behaviour(behaviour)
        runner.run([], false)
      end

      it "should run examples backwards if options.reverse is true" do
        @options.reverse = true

        reporter = mock("reporter")
        reporter.should_receive(:start).with(3)
        reporter.should_receive(:end)
        reporter.should_receive(:dump).and_return(0)
        @options.reporter = reporter

        runner = Spec::Runner::BehaviourRunner.new(@options)
        b1 = mock("b1")
        b1.should_receive(:number_of_examples).twice.and_return(1)
        b1.should_receive(:shared?).and_return(false)
        b1.should_receive(:set_sequence_numbers).with(12, true).and_return(18)

        b2 = mock("b2")
        b2.should_receive(:number_of_examples).twice.and_return(2)
        b2.should_receive(:shared?).and_return(false)
        b2.should_receive(:set_sequence_numbers).with(0, true).and_return(12)
        b2.should_receive(:run) do
          b1.should_receive(:run)
        end

        runner.add_behaviour(b1)
        runner.add_behaviour(b2)
    
        runner.run([], false)
      end
      
      it "should yield global configuration" do
        Spec::Runner.configure do |config|
          config.should equal(Spec::Runner.configuration)
        end
      end

      it "should pass its Description to the reporter" do
        behaviour = Spec::DSL::Behaviour.new("behaviour") do
          it "should" do
          end
        end
        
        reporter = mock("reporter", :null_object => true)
        reporter.should_receive(:add_behaviour).with(an_instance_of(Spec::DSL::Description))

        @options.reporter = reporter
        runner = Spec::Runner::BehaviourRunner.new(@options)
        runner.add_behaviour(behaviour)
        runner.run([], false)
      end
    end
  end
end
