require 'benchmark'
require 'tmpdir'
require 'csv'

namespace :benchmark do
  def generate_scenario_tasks(location, name)
    desc File.read(File.join(location, 'description'))
    task name => "#{name}:run"

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
      task :run => :generate do
        format = if RUBY_VERSION =~ /^1\.8/
                   Benchmark::FMTSTR
                 else
                   Benchmark::FORMAT
                 end

        report = []
        Benchmark.benchmark(Benchmark::CAPTION, 10, format, "> total:", "> avg:") do |b|
          times = []
          ENV['ITERATIONS'].to_i.times do |i|
            start_time = Time.now.to_i
            times << b.report("Run #{i + 1}") do
              @benchmark.run
            end
            report << [to_millis(start_time), to_millis(times.last.real), 200, true, name]
          end

          sum = times.inject(Benchmark::Tms.new, &:+)

          [sum, sum / times.length]
        end

        write_csv("#{name}.samples",
                  %w{timestamp elapsed responsecode success name},
                  report)
      end

      desc "Profile a single run of the #{name} scenario."
      task :profile => :generate do
        require 'ruby-prof'

        result = RubyProf.profile do
          @benchmark.run
        end

        printer = RubyProf::CallTreePrinter.new(result)
        File.open(File.join("callgrind.#{name}.#{Time.now.to_i}.trace"), "w") do |f|
          printer.print(f)
        end
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
