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
    end

    desc "Generate the scenario"
    task :generate => :setup do
      size = ENV['SIZE'].to_i
      environment = File.join(ENV['TARGET'], 'environments', 'benchmarking')
      templates = File.join('benchmarks', 'many_modules')

      mkdir_p(File.join(environment, 'modules'))
      mkdir_p(File.join(environment, 'manifests'))

      render(File.join(templates, 'site.pp.erb'),
             File.join(environment, 'manifests', 'site.pp'),
             :size => size)

      size.times do |i|
        module_name = "module#{i}"
        manifests = File.join(environment, 'modules', module_name, 'manifests')

        mkdir_p(manifests)

        render(File.join(templates, 'module', 'init.pp.erb'),
               File.join(manifests, 'init.pp'),
               :name => module_name)

        render(File.join(templates, 'module', 'internal.pp.erb'),
               File.join(manifests, 'internal.pp'),
               :name => module_name)
      end

      render(File.join(templates, 'puppet.conf.erb'),
             File.join(ENV['TARGET'], 'puppet.conf'),
             :location => ENV['TARGET'])
    end

    task :run => :generate do
      require 'puppet'
      include Benchmark

      config = File.join(ENV['TARGET'], 'puppet.conf')
      Puppet.initialize_settings(['--config', config])

      Benchmark.benchmark(CAPTION, 10, FORMAT, "> total:", "> avg:") do |b|
        times = []
        10.times do |i|
          times << b.report("Run #{i + 1}") do
            env = Puppet.lookup(:environments).get('benchmarking')
            node = Puppet::Node.new("testing", :environment => env)
            Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
          end
        end

        sum = times.inject(Benchmark::Tms.new, &:+)

        [sum, sum / times.length]
      end
    end
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end
end
