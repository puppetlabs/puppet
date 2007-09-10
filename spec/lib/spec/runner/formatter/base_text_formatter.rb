module Spec
  module Runner
    module Formatter
      # Baseclass for text-based formatters. Can in fact be used for
      # non-text based ones too - just ignore the +output+ constructor
      # argument.
      class BaseTextFormatter < BaseFormatter
        attr_writer :dry_run
        
        # Creates a new instance that will write to +where+. If +where+ is a
        # String, output will be written to the File with that name, otherwise
        # +where+ is exected to be an IO (or an object that responds to #puts and #write).
        def initialize(where)
          super(where)
          if where.is_a?(String)
            @output = File.open(where, 'w')
          elsif where == STDOUT
            @output = Kernel
            def @output.flush
              STDOUT.flush
            end
          else
            @output = where
          end
          @colour = false
          @dry_run = false
          @snippet_extractor = SnippetExtractor.new
          @pending_examples = []
        end
        
        def example_pending(behaviour_name, example_name, message)
          @pending_examples << ["#{behaviour_name} #{example_name}", message]
        end
        
        def colour=(colour)
          @colour = colour
          begin ; require 'Win32/Console/ANSI' if @colour && PLATFORM =~ /win32/ ; rescue LoadError ; raise "You must gem install win32console to use colour on Windows" ; end
        end

        def dump_failure(counter, failure)
          @output.puts
          @output.puts "#{counter.to_s})"
          @output.puts colourise("#{failure.header}\n#{failure.exception.message}", failure)
          @output.puts format_backtrace(failure.exception.backtrace)
          @output.flush
        end
        
        def colourise(s, failure)
          if(failure.expectation_not_met?)
            red(s)
          elsif(failure.pending_fixed?)
            blue(s)
          else
            magenta(s)
          end
        end
      
        def dump_summary(duration, example_count, failure_count, pending_count)
          return if @dry_run
          @output.puts
          @output.puts "Finished in #{duration} seconds"
          @output.puts

          summary = "#{example_count} example#{'s' unless example_count == 1}, #{failure_count} failure#{'s' unless failure_count == 1}"
          summary << ", #{pending_count} pending" if pending_count > 0  

          if failure_count == 0
            if pending_count > 0
              @output.puts yellow(summary)
            else
              @output.puts green(summary)
            end
          else
            @output.puts red(summary)
          end
          @output.flush
          dump_pending
        end

        def dump_pending
          unless @pending_examples.empty?
            @output.puts
            @output.puts "Pending:"
            @pending_examples.each do |pending_example|
              @output.puts "#{pending_example[0]} (#{pending_example[1]})" 
            end
          end
          @output.flush
        end
        
        def close
          if IO === @output
            @output.close 
          end
        end
        
        def format_backtrace(backtrace)
          return "" if backtrace.nil?
          backtrace.map { |line| backtrace_line(line) }.join("\n")
        end
      
      protected
      
        def backtrace_line(line)
          line.sub(/\A([^:]+:\d+)$/, '\\1:')
        end

        def colour(text, colour_code)
          return text unless @colour && output_to_tty?
          "#{colour_code}#{text}\e[0m"
        end

        def output_to_tty?
          begin
            @output == Kernel || @output.tty?
          rescue NoMethodError
            false
          end
        end
        
        def green(text); colour(text, "\e[32m"); end
        def red(text); colour(text, "\e[31m"); end
        def magenta(text); colour(text, "\e[35m"); end
        def yellow(text); colour(text, "\e[33m"); end
        def blue(text); colour(text, "\e[34m"); end
        
      end
    end
  end
end
