module Spec
  module Runner
    class BehaviourRunner
      
      def initialize(options, arg=nil)
        @behaviours = []
        @options = options
      end
    
      def add_behaviour(behaviour)
        if !specified_examples.nil? && !specified_examples.empty?
          behaviour.retain_examples_matching!(specified_examples)
        end
        @behaviours << behaviour if behaviour.number_of_examples != 0 && !behaviour.shared?
      end
      
      # Runs all behaviours and returns the number of failures.
      def run(paths, exit_when_done)
        prepare!(paths)
        begin
          run_behaviours
        rescue Interrupt
        ensure
          report_end
        end
        failure_count = report_dump
        
        heckle if(failure_count == 0 && !@options.heckle_runner.nil?)
        
        if(exit_when_done)
          exit_code = (failure_count == 0) ? 0 : 1
          exit(exit_code)
        end
        failure_count
      end
      
      def report_end
        @options.reporter.end
      end
      
      def report_dump
        @options.reporter.dump
      end
      
      def prepare!(paths)
        unless paths.nil? # It's nil when running single specs with ruby
          paths = find_paths(paths)
          sorted_paths = sort_paths(paths)
          load_specs(sorted_paths) # This will populate @behaviours via callbacks to add_behaviour
        end
        @options.reporter.start(number_of_examples)
        @behaviours.reverse! if @options.reverse
        set_sequence_numbers
      end

      def run_behaviours
        @behaviours.each do |behaviour|
          behaviour.run(@options.reporter, @options.dry_run, @options.reverse, @options.timeout)
        end
      end
    
      def number_of_examples
        @behaviours.inject(0) {|sum, behaviour| sum + behaviour.number_of_examples}
      end
      
      FILE_SORTERS = {
        'mtime' => lambda {|file_a, file_b| File.mtime(file_b) <=> File.mtime(file_a)}
      }
      
      def sorter(paths)
        FILE_SORTERS[@options.loadby]
      end
      
      def sort_paths(paths)
        sorter = sorter(paths)
        paths = paths.sort(&sorter) unless sorter.nil?
        paths
      end

    private
      
      # Sets the #number on each Example
      def set_sequence_numbers
        number = 0
        @behaviours.each do |behaviour|
          number = behaviour.set_sequence_numbers(number, @options.reverse)
        end
      end
      
      def find_paths(paths)
        result = []
        paths.each do |path|
          if File.directory?(path)
            result += Dir["#{path}/**/*.rb"]
          elsif File.file?(path)
            result << path
          else
            raise "File or directory not found: #{path}"
          end
        end
        result
      end
      
      def load_specs(paths)
        paths.each do |path|
          load path
        end
      end
      
      def specified_examples
        @options.examples
      end
      
      def heckle
        heckle_runner = @options.heckle_runner
        @options.heckle_runner = nil
        behaviour_runner = self.class.new(@options)
        behaviour_runner.instance_variable_set(:@behaviours, @behaviours)
        heckle_runner.heckle_with(behaviour_runner)
      end
    end
  end
end
