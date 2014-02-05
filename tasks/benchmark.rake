require 'benchmark'
require 'tmpdir'
require 'erb'
require 'ostruct'
require 'open3'

desc "Execute all puppet benchmarks."
task :benchmark => ["benchmark:many_modules"]

namespace :benchmark do
  desc "Benchmark scenario: many manifests spread across many modules.
Benchmark target: catalog compilation."
  task :many_modules => "many_modules:run"

  namespace :many_modules do
    task :setup do
      ENV['SIZE'] ||= '100'
      ENV['TARGET'] ||= Dir.mktmpdir("many_modules")
      ENV['TARGET'] = File.expand_path(ENV['TARGET'])

      mkdir_p(ENV['TARGET'])

      require File.expand_path(File.join('benchmarks', 'many_modules', 'benchmark.rb'))

      @benchmark = ManyModules.new(ENV['TARGET'], ENV['SIZE'].to_i)
    end

    desc "Generate the scenario"
    task :generate => :setup do
      @benchmark.generate
    end

    task :run => :generate do
      @benchmark.setup
      Benchmark.benchmark(Benchmark::CAPTION, 10, Benchmark::FORMAT, "> total:", "> avg:") do |b|
        times = []
        10.times do |i|
          times << b.report("Run #{i + 1}") do
            @benchmark.run
          end
        end

        sum = times.inject(Benchmark::Tms.new, &:+)

        [sum, sum / times.length]
      end
    end

    task :profile => :generate do
      require 'ruby-prof'

      @benchmark.setup
      result = RubyProf.profile do
        @benchmark.run
      end

      printer = RubyProf::CallTreePrinter.new(result)
      File.open(File.join("callgrind.many_modules.#{Time.now.to_i}.trace"), "w") do |f|
        printer.print(f)
      end

    end
  end
end
