# encoding: utf-8

require 'rubygems'
require 'thread'
begin
  require 'rspec'
  require 'rspec/core/formatters/helpers'
  require 'facter'
rescue LoadError
  # Don't define the task if we don't have rspec or facter present
else
  module Parallel
    module RSpec
      #
      # Responsible for buffering the output of RSpec's progress formatter.
      #
      class ProgressFormatBuffer
        attr_reader :pending_lines
        attr_reader :failure_lines
        attr_reader :examples
        attr_reader :failures
        attr_reader :pending
        attr_reader :failed_example_lines
        attr_reader :state

        module OutputState
          HEADER = 1
          PROGRESS = 2
          SUMMARY = 3
          PENDING = 4
          FAILURES = 5
          DURATION = 6
          COUNTS = 7
          FAILED_EXAMPLES = 8
        end

        def initialize(io, color)
          @io = io
          @color = color
          @state = OutputState::HEADER
          @pending_lines = []
          @failure_lines = []
          @examples = 0
          @failures = 0
          @pending = 0
          @failed_example_lines = []
        end

        def color?
          @color
        end

        def read
          # Parse and ignore the one line header
          if @state == OutputState::HEADER
            begin
              @io.readline
            rescue EOFError
              return nil
            end
            @state = OutputState::PROGRESS
            return ''
          end

          # If the progress has been read, parse the summary
          if @state == OutputState::SUMMARY
            parse_summary
            return nil
          end

          # Read the progress output up to 128 bytes at a time
          # 128 is a small enough number to show some progress, but not too small that
          # we're constantly writing synchronized output
          data = @io.read(128)
          return nil unless data

          data = @remainder + data if @remainder

          # Check for the end of the progress line
          if (index = data.index "\n")
            @state = OutputState::SUMMARY
            @remainder = data[(index+1)..-1]
            data = data[0...index]
          # Check for partial ANSI escape codes in colorized output
          elsif @color && !data.end_with?("\e[0m") && (index = data.rindex("\e[", -6))
            @remainder = data[index..-1]
            data = data[0...index]
          else
            @remainder = nil
          end

          data
        end

        private

        def parse_summary
          # If there is a remainder, concat it with the next line and handle each line
          unless @remainder.empty?
            lines = @remainder
            eof = false
            begin
              lines += @io.readline
            rescue EOFError
              eof = true
            end
            lines.each_line do |line|
              parse_summary_line line
            end
            return if eof
          end

          # Process the rest of the lines
          begin
            @io.each_line do |line|
              parse_summary_line line
            end
          rescue EOFError
          end
        end

        def parse_summary_line(line)
          line.chomp!
          return if line.empty?

          if line == 'Pending:'
            @status = OutputState::PENDING
            return
          elsif line == 'Failures:'
            @status = OutputState::FAILURES
            return
          elsif line == 'Failed examples:'
            @status = OutputState::FAILED_EXAMPLES
            return
          elsif (line.match /^Finished in ((\d+\.?\d*) minutes?)? ?(\d+\.?\d*) seconds?$/)
            @status = OutputState::DURATION
            return
          elsif (match = line.gsub(/\e\[\d+m/, '').match /^(\d+) examples?, (\d+) failures?(, (\d+) pending)?$/)
            @status = OutputState::COUNTS
            @examples = match[1].to_i
            @failures = match[2].to_i
            @pending = (match[4] || 0).to_i
            return
          end

          case @status
            when OutputState::PENDING
              @pending_lines << line
            when OutputState::FAILURES
              @failure_lines << line
            when OutputState::FAILED_EXAMPLES
              @failed_example_lines << line
          end
        end
      end

      #
      # Responsible for parallelizing spec testing.
      # Optional options list will be passed to rspec.
      #
      class Parallelizer
        # Number of processes to use
        attr_reader :process_count
        # Approximate size of each group of tests
        attr_reader :group_size
        # Options list for rspec
        attr_reader :options

        def initialize(process_count, group_size, color, options = [])
          @process_count = process_count
          @group_size = group_size
          @color = color
          @options = options
        end

        def color?
          @color
        end

        def run
          @start_time = Time.now

          groups = group_specs
          fail red('error: no specs were found') if groups.length == 0

          begin
            run_specs(groups, options)
          ensure
            groups.each do |file|
              File.unlink(file)
            end
          end
        end

        private

        def group_specs
          # Spawn the rspec_grouper utility to perform the test grouping
          # We do this in a separate process to limit this processes' long-running footprint
          io = IO.popen("ruby util/rspec_grouper #{@group_size}")

          header = true
          spec_group_files = []
          io.each_line do |line|
            line.chomp!
            header = false if line.empty?
            next if header || line.empty?
            spec_group_files << line
          end

          _, status = Process.waitpid2(io.pid)
          io.close

          fail red('error: no specs were found.') unless status.success?
          spec_group_files
        end

        def run_specs(groups, options)
          puts "Processing #{groups.length} spec group(s) with #{@process_count} worker(s)"

          interrupted = false
          success = true
          worker_threads = []
          group_index = -1
          pids = Array.new(@process_count)
          mutex = Mutex.new

          # Handle SIGINT by killing child processes
          original_handler = Signal.trap :SIGINT do
            break if interrupted
            interrupted = true

            # Can't synchronize in a trap context, so read dirty
            pids.each do |pid|
              begin
                Process.kill(:SIGKILL, pid) if pid
              rescue Errno::ESRCH
              end
            end
            puts yellow("\nshutting down...")
          end

          buffers = []

          process_count.times do |thread_id|
            worker_threads << Thread.new do
              while !interrupted do
                # Get the spec file for this rspec run
                group = mutex.synchronize { if group_index < groups.length then groups[group_index += 1] else nil end }
                break unless group && !interrupted

                # Spawn the worker process with redirected output
                options_string = options ? options.join(' ') : ''
                io = IO.popen("ruby util/rspec_runner #{group} #{options_string}")
                pids[thread_id] = io.pid

                # TODO: make the buffer pluggable to handle other output formats like documentation
                buffer = ProgressFormatBuffer.new(io, @color)

                # Process the output
                while !interrupted
                  output = buffer.read
                  break unless output && !interrupted
                  next if output.empty?
                  mutex.synchronize { print output }
                end

                # Kill the process if we were interrupted, just to be sure
                if interrupted
                  begin
                    Process.kill(:SIGKILL, pids[thread_id])
                  rescue Errno::ESRCH
                  end
                end

                # Reap the process
                result = Process.waitpid2(pids[thread_id])[1].success?
                io.close
                pids[thread_id] = nil
                mutex.synchronize do
                  buffers << buffer
                  success &= result
                end
              end
            end
          end

          # Join all worker threads
          worker_threads.each do |thread|
            thread.join
          end

          Signal.trap :SIGINT, original_handler
          fail yellow('execution was interrupted') if interrupted

          dump_summary buffers
          success
        end

        def colorize(text, color_code)
          if @color
            "#{color_code}#{text}\e[0m"
          else
            text
          end
        end

        def red(text)
          colorize(text, "\e[31m")
        end

        def green(text)
          colorize(text, "\e[32m")
        end

        def yellow(text)
          colorize(text, "\e[33m")
        end

        def dump_summary(buffers)
          puts

          # Print out the pending tests
          print_header = true
          buffers.each do |buffer|
            next if buffer.pending_lines.empty?
            if print_header
              puts "\nPending:"
              print_header = false
            end
            puts buffer.pending_lines
          end

          # Print out the failures
          print_header = true
          buffers.each do |buffer|
            next if buffer.failure_lines.empty?
            if print_header
              puts "\nFailures:"
              print_header = false
            end
            puts
            puts buffer.failure_lines
          end

          # Print out the run time
          puts "\nFinished in #{::RSpec::Core::Formatters::Helpers.format_duration(Time.now - @start_time)}"

          # Count all of the examples
          examples = 0
          failures = 0
          pending = 0
          buffers.each do |buffer|
            examples += buffer.examples
            failures += buffer.failures
            pending += buffer.pending
          end
          if failures > 0
            puts red(summary_count_line(examples, failures, pending))
          elsif pending > 0
            puts yellow(summary_count_line(examples, failures, pending))
          else
            puts green(summary_count_line(examples, failures, pending))
          end

          # Print out the failed examples
          print_header = true
          buffers.each do |buffer|
            next if buffer.failed_example_lines.empty?
            if print_header
              puts "\nFailed examples:"
              print_header = false
            end
            puts buffer.failed_example_lines
          end
        end

        def summary_count_line(examples, failures, pending)
          summary = ::RSpec::Core::Formatters::Helpers.pluralize(examples, "example")
          summary << ", " << ::RSpec::Core::Formatters::Helpers.pluralize(failures, "failure")
          summary << ", #{pending} pending" if pending > 0
          summary
        end
      end
    end
  end

  namespace 'parallel' do
    def color_output?
      # Check with RSpec to see if color is enabled
      config = ::RSpec::Core::Configuration.new
      config.error_stream = $stderr
      config.output_stream = $stdout
      options = ::RSpec::Core::ConfigurationOptions.new []
      options.configure config
      config.color
    end

    desc 'Runs specs in parallel. Extra args are passed to rspec.'
    task 'spec', [:process_count, :group_size] do |_, args|
      # Default group size in rspec examples
      DEFAULT_GROUP_SIZE = 1000

      process_count = [(args[:process_count] || Facter.value("processorcount")).to_i, 1].max
      group_size = [(args[:group_size] || DEFAULT_GROUP_SIZE).to_i, 1].max

      abort unless Parallel::RSpec::Parallelizer.new(process_count, group_size, color_output?, args.extras).run
    end
  end
end
