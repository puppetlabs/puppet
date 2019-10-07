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

    50.times do
    envs.clear('benchmarking')
      node = Puppet::Node.new('testing', :environment => envs.get('benchmarking'))
      Puppet::Resource::Catalog.indirection.find('testing', :use_node => node)
    end
  end

  def benchmark_count
    bc = @@benchmark_count
    @@benchmark_count += 1
    bc
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    modules = File.join(environment, 'modules')
    templates = File.join('benchmarks', 'dependency_loading')

    mkdir_p(modules)
    mkdir_p(File.join(environment, 'manifests'))

    module_count = @size * 2
    modula = 10
    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => module_count, :modula => modula)

    module_count.times do |i|
      module_name = "module#{i}"
      module_base = File.join(modules, module_name)
      manifests = File.join(module_base, 'manifests')
      global_module_functions = File.join(module_base, 'lib', 'puppet', 'functions')
      module_functions = File.join(global_module_functions, module_name)

      mkdir_p(manifests)
      mkdir_p(module_functions)

      File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
        JSON.dump({
          'name' => "tester-#{module_name}",
          'author' => 'Puppet Labs tester',
          'license' => 'Apache 2.0',
          'version' => '1.0.0',
          'summary' => 'Benchmark module',
          'dependencies' => i > 0 ? dependency_to(i - 1) : [],
          'source' => ''
        }, f)
      end

      if (i + 1) % modula == 0
        render(File.join(templates, 'module', 'init.pp.erb'),
               File.join(manifests, 'init.pp'),
               :name => module_name, :other => "module#{i - 1}")
      else
        render(File.join(templates, 'module', 'init.pp_no_call.erb'),
          File.join(manifests, 'init.pp'),
          :name => module_name)
      end

      function_template = File.join(templates, 'module', 'function.erb')
      render(function_template, File.join(module_functions, "f#{module_name}.rb"), :name => module_name)
      global_function_template = File.join(templates, 'module', 'global_function.erb')
      render(global_function_template, File.join(global_module_functions, "f#{module_name}.rb"), :name => module_name)
    end

    render(File.join(templates, 'puppet.conf.erb'),
           File.join(@target, 'puppet.conf'),
           :location => @target)
  end

  def dependency_to(n)
    [ {'name' => "tester-module#{n}", 'version_requirement' => '1.0.0'} ]
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    site.filename = erb_file
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end
end
