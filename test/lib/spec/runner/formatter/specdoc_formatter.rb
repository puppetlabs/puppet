module Spec
  module Runner
    module Formatter
      class SpecdocFormatter < BaseTextFormatter      
        def add_context(name, first)
          @output.puts
          @output.puts name
          STDOUT.flush
        end
      
        def spec_failed(name, counter, failure)
          @output.puts failure.expectation_not_met? ? red("- #{name} (FAILED - #{counter})") : magenta("- #{name} (ERROR - #{counter})")
          STDOUT.flush
        end
      
        def spec_passed(name)
          @output.print green("- #{name}\n")
          STDOUT.flush
        end
      end
    end
  end
end