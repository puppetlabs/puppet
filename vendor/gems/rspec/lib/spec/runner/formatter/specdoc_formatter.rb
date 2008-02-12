module Spec
  module Runner
    module Formatter
      class SpecdocFormatter < BaseTextFormatter      
        def add_behaviour(name)
          @output.puts
          @output.puts name
          @output.flush
        end
      
        def example_failed(example, counter, failure)
          @output.puts failure.expectation_not_met? ? red("- #{example.description} (FAILED - #{counter})") : magenta("- #{example.description} (ERROR - #{counter})")
          @output.flush
        end
      
        def example_passed(example)
          @output.puts green("- #{example.description}")
          @output.flush
        end
        
        def example_pending(behaviour_name, example_name, message)
          super
          @output.puts yellow("- #{example_name} (PENDING: #{message})")
          @output.flush
        end
      end
    end
  end
end
