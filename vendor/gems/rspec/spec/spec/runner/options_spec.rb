require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Runner
    describe Options do
      before do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err, @out)
      end

      it "instantiates empty arrays" do
        @options.examples.should == []
        @options.formatters.should == []
      end

      it "defaults to QuietBacktraceTweaker" do
        @options.backtrace_tweaker.class.should == QuietBacktraceTweaker
      end

      it "defaults to no dry_run" do
        @options.dry_run.should == false
      end

      it "parse_diff sets context_lines" do
        @options.parse_diff nil
        @options.context_lines.should == 3
      end

      it "defaults diff to unified" do
        @options.parse_diff nil
        @options.diff_format.should == :unified
      end

      it "should use unified diff format option when format is unified" do
        @options.parse_diff 'unified'
        @options.diff_format.should == :unified
        @options.differ_class.should equal(Spec::Expectations::Differs::Default)
      end

      it "should use context diff format option when format is context" do
        @options.parse_diff 'context'
        @options.diff_format.should == :context
        @options.differ_class.should == Spec::Expectations::Differs::Default
      end

      it "should use custom diff format option when format is a custom format" do
        @options.parse_diff "Custom::Formatter"
        @options.diff_format.should == :custom
        @options.differ_class.should == Custom::Formatter
      end

      it "should print instructions about how to fix missing differ" do
        lambda { @options.parse_diff "Custom::MissingDiffer" }.should raise_error(NameError)
        @err.string.should match(/Couldn't find differ class Custom::MissingDiffer/n)
      end      

      it "should print instructions about how to fix bad formatter" do
        lambda do
          @options.parse_format "Custom::BadFormatter"
        end.should raise_error(NameError, /undefined local variable or method `bad_method'/)
      end      

      it "parse_example sets single example when argument not a file" do
        example = "something or other"
        File.file?(example).should == false
        @options.parse_example example
        @options.examples.should eql(["something or other"])
      end

      it "parse_example sets examples to contents of file" do
        example = "#{File.dirname(__FILE__)}/examples.txt"
        File.should_receive(:file?).with(example).and_return(true)
        file = StringIO.new("Sir, if you were my husband, I would poison your drink.\nMadam, if you were my wife, I would drink it.")
        File.should_receive(:open).with(example).and_return(file)
        
        @options.parse_example example
        @options.examples.should eql([
          "Sir, if you were my husband, I would poison your drink.",
          "Madam, if you were my wife, I would drink it."
        ])
      end
    end

    describe Options, "splitting class names and args" do
      before do
        @err = StringIO.new('')
        @out = StringIO.new('')
        @options = Options.new(@err, @out)
      end
      
      it "should split class names with args" do
        @options.split_at_colon('Foo').should == ['Foo', nil]
        @options.split_at_colon('Foo:arg').should == ['Foo', 'arg']
        @options.split_at_colon('Foo::Bar::Zap:arg').should == ['Foo::Bar::Zap', 'arg']
        @options.split_at_colon('Foo:arg1,arg2').should == ['Foo', 'arg1,arg2']
        @options.split_at_colon('Foo::Bar::Zap:arg1,arg2').should == ['Foo::Bar::Zap', 'arg1,arg2']
        @options.split_at_colon('Foo::Bar::Zap:drb://foo,drb://bar').should == ['Foo::Bar::Zap', 'drb://foo,drb://bar']
      end

      it "should raise error when splitting something starting with a number" do
        lambda { @options.split_at_colon('') }.should raise_error("Couldn't parse \"\"")
      end

      it "should raise error when not class name" do
        lambda do
          @options.load_class('foo', 'fruit', '--food')
        end.should raise_error('"foo" is not a valid class name')
      end
    end

    describe Options, "receiving create_behaviour_runner" do
      before do
        @err = StringIO.new
        @out = StringIO.new
        @options = Options.new(@err, @out)
      end

      it "should fail when custom runner not found" do
        @options.runner_arg = "Whatever"
        lambda { @options.create_behaviour_runner }.should raise_error(NameError)
        @err.string.should match(/Couldn't find behaviour runner class/)
      end

      it "should fail when custom runner not valid class name" do
        @options.runner_arg = "whatever"
        lambda { @options.create_behaviour_runner }.should raise_error('"whatever" is not a valid class name')
        @err.string.should match(/"whatever" is not a valid class name/)
      end

      it "returns nil when generate is true" do
        @options.generate = true
        @options.create_behaviour_runner.should == nil
      end

      it "returns a BehaviourRunner by default" do
        runner = @options.create_behaviour_runner
        runner.class.should == BehaviourRunner
      end

      it "does not set Expectations differ when differ_class is not set" do
        @options.differ_class = nil
        Spec::Expectations.should_not_receive(:differ=)
        @options.create_behaviour_runner
      end

      it "sets Expectations differ when differ_class is set" do
        @options.differ_class = Spec::Expectations::Differs::Default
        Spec::Expectations.should_receive(:differ=).with(anything()).and_return do |arg|
          arg.class.should == Spec::Expectations::Differs::Default
        end
        @options.configure
      end

      it "creates a Reporter" do
        formatter = ::Spec::Runner::Formatter::BaseFormatter.new(:somewhere)
        @options.formatters << formatter
        reporter = Reporter.new(@formatters, @backtrace_tweaker)
        Reporter.should_receive(:new).with(@options.formatters, @options.backtrace_tweaker).and_return(reporter)
        @options.configure
        @options.reporter.should === reporter
      end

      it "sets colour and dry_run on the formatters" do
        @options.colour = true
        @options.dry_run = true
        formatter = ::Spec::Runner::Formatter::BaseTextFormatter.new(:somewhere)
        formatter.should_receive(:colour=).with(true)
        formatter.should_receive(:dry_run=).with(true)
        @options.formatters << formatter
        @options.configure
      end
    end
  end
end
