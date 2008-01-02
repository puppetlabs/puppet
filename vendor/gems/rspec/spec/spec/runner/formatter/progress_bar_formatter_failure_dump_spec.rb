require File.dirname(__FILE__) + '/../../../spec_helper.rb'

module Spec
  module Runner
    module Formatter
      describe "ProgressBarFormatter failure dump with NoisyBacktraceTweaker" do
        before(:each) do
          @io = StringIO.new
          @reporter = Reporter.new([ProgressBarFormatter.new(@io)], NoisyBacktraceTweaker.new)
          @reporter.add_behaviour(Spec::DSL::Description.new("context"))
        end

        it "should end with line break" do
          error=Spec::Expectations::ExpectationNotMetError.new("message")
          set_backtrace(error)
          @reporter.example_finished("spec", error, "spec")
          @reporter.dump
          @io.string.should match(/\n\z/)
        end

        it "should include context and spec name in backtrace if error in spec" do
          error=RuntimeError.new("message")
          set_backtrace(error)
          @reporter.example_finished("spec", error, "spec")
          @reporter.dump
          @io.string.should match(/RuntimeError in 'context spec'/)
        end

        def set_backtrace(error)
          error.set_backtrace(["/a/b/c/d/e.rb:34:in `whatever'"])
        end

      end
    end
  end
end
