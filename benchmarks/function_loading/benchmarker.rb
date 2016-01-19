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
    envs = Puppet.lookup(:environments)

    envs.clear('benchmarking')
#    # Uncomment to get some basic memory statistics
#    ObjectSpace.garbage_collect
#    result = {}
#    ObjectSpace.count_objects(result)
#    puts "C(#{result[:T_CLASS]}) O(#{result[:T_OBJECT]}) F(#{result[:FREE]}) #{result[:T_CLASS] + result[:T_OBJECT]}"
    node = Puppet::Node.new('testing', :environment => envs.get('benchmarking'))
    Puppet::Resource::Catalog.indirection.find('testing', :use_node => node)
  end

  def benchmark_count
    bc = @@benchmark_count
    @@benchmark_count += 1
    bc
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    modules = File.join(environment, 'modules')
    env_functions = File.join(environment, 'lib', 'puppet', 'functions', 'environment')
    templates = File.join('benchmarks', 'function_loading')

    mkdir_p(modules)
    mkdir_p(env_functions)
    mkdir_p(File.join(environment, 'manifests'))

    module_count = @size / 5
    function_count = @size * 3
    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => module_count,
           :function_count => function_count)

    env_function_template = File.join(templates, 'env_function.erb')
    function_count.times { |n| render(env_function_template, File.join(env_functions, "f#{n}.rb"), :n => n) }

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
          'dependencies' => dependencies_for(i),
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

  def dependencies_for(n)
    return [] if n == 0
    n.times.map do |m|
      {'name' => "tester-module#{m}", 'version_requirement' => '1.0.0'}
    end
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    site.filename = erb_file
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end
end
