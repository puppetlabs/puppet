module Spec
  module Runner
    module Formatter
      class RdocFormatter < BaseTextFormatter
        def add_behaviour(name)
          @output.puts "# #{name}"
        end
  
        def example_passed(example)
          @output.puts "# * #{example.description}"
          @output.flush
        end

        def example_failed(example, counter, failure)
          @output.puts "# * #{example.description} [#{counter} - FAILED]"
        end
        
        def example_pending(behaviour_name, example_name, message)
          @output.puts "# * #{behaviour_name} #{example_name} [PENDING: #{message}]"
        end
      end
    end
  end
end
