require 'erb'
require 'ostruct'
require 'fileutils'
require 'json'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = size
    @@benchmark_count ||= 0
  end

  def setup
    require 'puppet'
    config = File.join(@target, 'puppet.conf')
    Puppet.initialize_settings(['--config', config])
  end

  def run(args=nil)
    env = Puppet.lookup(:environments).get("benchmarking#{benchmark_count}")
    node = Puppet::Node.new("testing", :environment => env)
    Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
  end

  def benchmark_count
    bc = @@benchmark_count
    @@benchmark_count += 1
    bc
  end

  def generate
    # We need a new environment for each iteration
    ENV['ITERATIONS'].to_i.times { |c| generate_env(c) }
  end

  def generate_env(c)
    environment = File.join(@target, 'environments', "benchmarking#{c}")
    modules = File.join(environment, 'modules')
    templates = File.join('benchmarks', 'function_loading')

    mkdir_p(modules)
    mkdir_p(File.join(environment, 'manifests'))

    module_count = @size / 10
    function_count = @size * 10
    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => module_count)

    module_count.times do |i|
      module_name = "module#{i}"
      module_base = File.join(modules, module_name)
      manifests = File.join(module_base, 'manifests')
      module_functions = File.join(module_base, 'lib', 'puppet', 'functions', module_name)

      mkdir_p(manifests)
      mkdir_p(module_functions)

      File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
        JSON.dump({
          'name' => "tester-#{module_name}",
          'author' => 'Puppet Labs tester',
          'license' => 'Apache 2.0',
          'version' => '1.0.0',
          'summary' => 'Benchmark module',
          'dependencies' => i > 0 ? [{'name' => "tester-module#{i-1}", 'version_requirement' => '1.0.0' }] : [],
          'source' => ''
        }, f)
      end

      render(File.join(templates, 'module', 'init.pp.erb'),
             File.join(manifests, 'init.pp'),
             :name => module_name, :mc => i, :function_count => function_count)

      function_template = File.join(templates, 'module', 'function.erb')
      function_count.times do |n|
        render(function_template,
               File.join(module_functions, "f#{n}.rb"),
               :name => module_name, :n => n)
      end
    end

    render(File.join(templates, 'puppet.conf.erb'),
           File.join(@target, 'puppet.conf'),
           :location => @target)
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end
end
