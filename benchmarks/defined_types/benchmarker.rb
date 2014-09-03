require 'erb'
require 'ostruct'
require 'fileutils'
require 'json'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = size
  end

  def setup
    require 'puppet'
    config = File.join(@target, 'puppet.conf')
    Puppet.initialize_settings(['--config', config])
  end

  def run(args=nil)
    env = Puppet.lookup(:environments).get('benchmarking')
    node = Puppet::Node.new("testing", :environment => env)
    Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'defined_types')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => @size)

    @size.times do |i|
      module_name = "module#{i}"
      module_base = File.join(environment, 'modules', module_name)
      manifests = File.join(module_base, 'manifests')

      mkdir_p(manifests)

      File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
        JSON.dump({
          "types" => [],
          "source" => "",
          "author" => "Defined Types Benchmark",
          "license" => "Apache 2.0",
          "version" => "1.0.0",
          "description" => "Defined Types benchmark module #{i}",
          "summary" => "Just this benchmark module, you know?",
          "dependencies" => [],
        }, f)
      end

      render(File.join(templates, 'module', 'testing.pp.erb'),
             File.join(manifests, 'testing.pp'),
             :name => module_name)
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
