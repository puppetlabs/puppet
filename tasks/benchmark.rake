require 'benchmark'
require 'tmpdir'

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

      desc "Generate the #{name} scenario."
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
        Benchmark.benchmark(Benchmark::CAPTION, 10, format, "> total:", "> avg:") do |b|
          times = []
          ENV['ITERATIONS'].to_i.times do |i|
            times << b.report("Run #{i + 1}") do
              @benchmark.run
            end
          end

          sum = times.inject(Benchmark::Tms.new, &:+)

          [sum, sum / times.length]
        end
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
    end
  end

  Dir.glob('benchmarks/*') do |location|
    generate_scenario_tasks(location, File.basename(location))
  end
end
