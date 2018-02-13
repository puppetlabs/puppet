require 'benchmark'
require 'tmpdir'
require 'csv'
require 'objspace'

namespace :benchmark do
  def generate_scenario_tasks(location, name)
    desc File.read(File.join(location, 'description'))
    task name => "#{name}:run"
    # Load a BenchmarkerTask to handle config of the benchmark
    task_handler_file = File.expand_path(File.join(location, 'benchmarker_task.rb'))
    if File.exist?(task_handler_file)
      require task_handler_file
      run_args = BenchmarkerTask.run_args
    else
      run_args = []
    end

    namespace name do
      task :setup do
        ENV['ITERATIONS'] ||= '10'
        ENV['SIZE'] ||= '100'
        ENV['TARGET'] ||= Dir.mktmpdir(name)
        ENV['TARGET'] = File.expand_path(ENV['TARGET'])

        mkdir_p(ENV['TARGET'])

        require File.expand_path(File.join(location, 'benchmarker.rb'))

        @benchmark = Benchmarker.new(ENV['TARGET'], ENV['SIZE'].to_i)
      end

      task :generate => :setup do
        @benchmark.generate
        @benchmark.setup
      end

      desc "Run the #{name} scenario."
      task :run, [*run_args] =>  :generate do |_, args|
        report = []
        details = []
        Benchmark.benchmark(Benchmark::CAPTION, 10, Benchmark::FORMAT, "> total:", "> avg:") do |b|
          times = []
          ENV['ITERATIONS'].to_i.times do |i|
            start_time = Time.now.to_i
            times << b.report("Run #{i + 1}") do
              details << @benchmark.run(args)
            end
            report << [to_millis(start_time), to_millis(times.last.real), 200, true, name]
          end

          sum = times.inject(Benchmark::Tms.new, &:+)

          [sum, sum / times.length]
        end

        write_csv("#{name}.samples",
                  %w{timestamp elapsed responsecode success name},
                  report)

        # report details, if any were produced
        if details[0].is_a?(Array) && details[0][0].is_a?(Benchmark::Tms)
          # assume all entries are Tms if the first is
          # turn each into a hash of label => tms (since labels are lost when doing arithmetic on Tms)
          hashed = details.reduce([]) do |memo, measures|
            memo << measures.reduce({}) {|memo2, measure| memo2[measure.label] = measure; memo2}
            memo
          end
          # sum across all hashes
          result = {}

          hashed_totals = hashed.reduce {|memo, h| memo.merge(h) {|k, old, new| old + new }}
          # average the totals
          hashed_totals.keys.each {|k| hashed_totals[k] /= details.length }
          min_width = 14
          max_width = (hashed_totals.keys.map(&:length) << min_width).max
          puts "\n"
          puts sprintf("%2$*1$s %3$s", -max_width, 'Details (avg)', "      user     system      total        real")
          puts "-" * (46 + max_width)
          hashed_totals.sort.each {|k,v| puts sprintf("%2$*1$s %3$s", -max_width, k, v.format) }
        end
      end

      desc "Profile a single run of the #{name} scenario."
      task :profile, [:warm_up_runs, *run_args] => :generate do |_, args|
        warm_up_runs = (args[:warm_up_runs] || '0').to_i
        warm_up_runs.times do
          @benchmark.run(args)
        end

        require 'ruby-prof'

        result = RubyProf.profile do
          @benchmark.run(args)
        end

        printer = RubyProf::CallTreePrinter.new(result)
        printer.print(:profile => name, :path => ENV['TARGET'])
        path = File.join(ENV['TARGET'], "#{name}.callgrind.out.#{$$}")
        puts "Generated callgrind file: #{path}"
      end

      desc "Print a memory profile of the #{name} scenario."
      task :memory_profile, [*run_args] => :generate do |_, args|
        require 'memory_profiler'

        report = MemoryProfiler.report do
          @benchmark.run(args)
        end

        path = "mem_profile_#{$PID}"
        report.pretty_print(to_file: path)

        puts "Generated memory profile: #{File.absolute_path(path)}"
      end

      desc "Generate a heap dump with object allocation tracing of the #{name} scenario."
      task :heap_dump, [*run_args] => :generate do |_, args|
        ObjectSpace.trace_object_allocations_start

        if ENV['DISABLE_GC']
          GC.disable
        end

        @benchmark.run(args)

        unless ENV['DISABLE_GC']
          GC.start
        end

        path = "heap_#{$PID}.json"
        File.open(path, 'w') do |file|
          ObjectSpace.dump_all(output: file)
        end

        puts "Generated heap dump: #{File.absolute_path(path)}"
      end

      def to_millis(seconds)
        (seconds * 1000).round
      end

      def write_csv(file, header, data)
        CSV.open(file, 'w') do |csv|
          csv << header
          data.each do |line|
            csv << line
          end
        end
      end
    end
  end

  scenarios = []
  Dir.glob('benchmarks/*') do |location|
    name = File.basename(location)
    scenarios << name
    generate_scenario_tasks(location, File.basename(location))
  end

  namespace :all do
    desc "Profile all of the scenarios. (#{scenarios.join(', ')})"
    task :profile do
      scenarios.each do |name|
        sh "rake benchmark:#{name}:profile"
      end
    end

    desc "Run all of the scenarios. (#{scenarios.join(', ')})"
    task :run do
      scenarios.each do |name|
        sh "rake benchmark:#{name}:run"
      end
    end
  end
end
