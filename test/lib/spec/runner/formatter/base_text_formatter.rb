module Spec
  module Runner
    module Formatter
      # Baseclass for text-based formatters. Can in fact be used for
      # non-text based ones too - just ignore the +output+ constructor
      # argument.
      class BaseTextFormatter
        def initialize(output, dry_run=false, colour=false)
          @output = output
          @dry_run = dry_run
          @colour = colour
          begin ; require 'Win32/Console/ANSI' if @colour && PLATFORM =~ /win32/ ; rescue LoadError ; raise "You must gem install win32console to use colour on Windows" ; end
	      end

        # This method is invoked before any specs are run, right after
        # they have all been collected. This can be useful for special
        # formatters that need to provide progress on feedback (graphical ones)
        #
        # This method will only be invoked once, and the next one to be invoked
        # is #add_context
        def start(spec_count)
        end

        # This method is invoked at the beginning of the execution of each context.
        # +name+ is the name of the context and +first+ is true if it is the
        # first context - otherwise it's false.
        #
        # The next method to be invoked after this is #spec_started
        def add_context(name, first)
        end

        # This method is invoked right before a spec is executed.
        # The next method to be invoked after this one is one of #spec_failed
        # or #spec_passed.
        def spec_started(name)
        end

        # This method is invoked when a spec fails, i.e. an exception occurred
        # inside it (such as a failed should or other exception). +name+ is the name
        # of the specification. +counter+ is the sequence number of the failure
        # (starting at 1) and +failure+ is the associated Failure object.
        def spec_failed(name, counter, failure)
        end

        # This method is invoked when a spec passes. +name+ is the name of the
        # specification.
        def spec_passed(name)
        end

        # This method is invoked after all of the specs have executed. The next method
        # to be invoked after this one is #dump_failure (once for each failed spec),
        def start_dump
        end

        # Dumps detailed information about a spec failure.
        # This method is invoked for each failed spec after all specs have run. +counter+ is the sequence number
        # of the associated spec. +failure+ is a Failure object, which contains detailed
        # information about the failure.
        def dump_failure(counter, failure)
          @output.puts
          @output.puts "#{counter.to_s})"
          if(failure.expectation_not_met?)
            @output.puts red(failure.header)
            @output.puts red(failure.exception.message)
          else
            @output.puts magenta(failure.header)
            @output.puts magenta(failure.exception.message)
          end
          @output.puts format_backtrace(failure.exception.backtrace)
          STDOUT.flush
        end
      
        # This method is invoked at the very end.
        def dump_summary(duration, spec_count, failure_count)
          return if @dry_run
          @output.puts
          @output.puts "Finished in #{duration} seconds"
          @output.puts
          summary = "#{spec_count} specification#{'s' unless spec_count == 1}, #{failure_count} failure#{'s' unless failure_count == 1}"
          if failure_count == 0
            @output.puts green(summary)
          else
            @output.puts red(summary)
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
        
        def red(text); colour(text, "\e[31m"); end
        def green(text); colour(text, "\e[32m"); end
        def magenta(text); colour(text, "\e[35m"); end
        
      end
    end
  end
end
