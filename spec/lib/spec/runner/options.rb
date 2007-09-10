module Spec
  module Runner
    class Options
      BUILT_IN_FORMATTERS = {
        'specdoc'  => Formatter::SpecdocFormatter,
        's'        => Formatter::SpecdocFormatter,
        'html'     => Formatter::HtmlFormatter,
        'h'        => Formatter::HtmlFormatter,
        'rdoc'     => Formatter::RdocFormatter,
        'r'        => Formatter::RdocFormatter,
        'progress' => Formatter::ProgressBarFormatter,
        'p'        => Formatter::ProgressBarFormatter,
        'failing_examples' => Formatter::FailingExamplesFormatter,
        'e'        => Formatter::FailingExamplesFormatter,
        'failing_behaviours' => Formatter::FailingBehavioursFormatter,
        'b'        => Formatter::FailingBehavioursFormatter
      }
      
      attr_accessor(
        :backtrace_tweaker,
        :colour,
        :context_lines,
        :diff_format,
        :differ_class,
        :dry_run,
        :examples,
        :failure_file,
        :formatters,
        :generate,
        :heckle_runner,
        :line_number,
        :loadby,
        :reporter,
        :reverse,
        :timeout,
        :verbose,
        :runner_arg,
        :behaviour_runner
      )

      def initialize(err, out)
        @err, @out = err, out
        @backtrace_tweaker = QuietBacktraceTweaker.new
        @examples = []
        @formatters = []
        @colour = false
        @dry_run = false
      end

      def configure
        configure_formatters
        create_reporter
        configure_differ
        create_behaviour_runner
      end

      def create_behaviour_runner
        return nil if @generate
        @behaviour_runner = if @runner_arg
          klass_name, arg = split_at_colon(@runner_arg)
          runner_type = load_class(klass_name, 'behaviour runner', '--runner')
          runner_type.new(self, arg)
        else
          BehaviourRunner.new(self)
        end
      end

      def configure_formatters
        @formatters.each do |formatter|
          formatter.colour = @colour if formatter.respond_to?(:colour=)
          formatter.dry_run = @dry_run if formatter.respond_to?(:dry_run=)
        end
      end

      def create_reporter
        @reporter = Reporter.new(@formatters, @backtrace_tweaker)
      end

      def configure_differ
        if @differ_class
          Spec::Expectations.differ = @differ_class.new(@diff_format, @context_lines, @colour)
        end
      end

      def parse_diff(format)
        @context_lines = 3
        case format
          when :context, 'context', 'c'
            @diff_format  = :context
          when :unified, 'unified', 'u', '', nil
            @diff_format  = :unified
        end

        if [:context,:unified].include? @diff_format
          require 'spec/expectations/differs/default'
          @differ_class = Spec::Expectations::Differs::Default
        else
          @diff_format  = :custom
          @differ_class = load_class(format, 'differ', '--diff')
        end
      end

      def parse_example(example)
        if(File.file?(example))
          @examples = File.open(example).read.split("\n")
        else
          @examples = [example]
        end
      end

      def parse_format(format_arg)
        format, where = split_at_colon(format_arg)
        # This funky regexp checks whether we have a FILE_NAME or not
        if where.nil?
          raise "When using several --format options only one of them can be without a file" if @out_used
          where = @out
          @out_used = true
        end

        formatter_type = BUILT_IN_FORMATTERS[format] || load_class(format, 'formatter', '--format')
        @formatters << formatter_type.new(where)
      end

      def parse_require(req)
        req.split(",").each{|file| require file}
      end

      def parse_heckle(heckle)
        heckle_require = [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM} ? 'spec/runner/heckle_runner_unsupported' : 'spec/runner/heckle_runner'
        require heckle_require
        @heckle_runner = HeckleRunner.new(heckle)
      end

      def parse_generate_options(options_file, args_copy, out_stream)
        # Remove the --generate-options option and the argument before writing to file
        index = args_copy.index("-G") || args_copy.index("--generate-options")
        args_copy.delete_at(index)
        args_copy.delete_at(index)
        File.open(options_file, 'w') do |io|
          io.puts args_copy.join("\n")
        end
        out_stream.puts "\nOptions written to #{options_file}. You can now use these options with:"
        out_stream.puts "spec --options #{options_file}"
        @generate = true
      end

      def split_at_colon(s)
        if s =~ /([a-zA-Z_]+(?:::[a-zA-Z_]+)*):?(.*)/
          arg = $2 == "" ? nil : $2
          [$1, arg]
        else
          raise "Couldn't parse #{s.inspect}"
        end
      end
      
      def load_class(name, kind, option)
        if name =~ /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/
          arg = $2 == "" ? nil : $2
          [$1, arg]
        else
          m = "#{name.inspect} is not a valid class name"
          @err.puts m
          raise m
        end
        begin
          eval(name, binding, __FILE__, __LINE__)
        rescue NameError => e
          @err.puts "Couldn't find #{kind} class #{name}"
          @err.puts "Make sure the --require option is specified *before* #{option}"
          if $_spec_spec ; raise e ; else exit(1) ; end
        end
      end
    end
  end
end
