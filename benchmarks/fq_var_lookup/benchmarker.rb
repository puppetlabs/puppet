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
    templates = File.join('benchmarks', 'fq_var_lookup')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => @size)


    module_name = "tst_generate"
    module_base = File.join(environment, 'modules', module_name)
    manifests = File.join(module_base, 'manifests')

    mkdir_p(manifests)

    File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
      JSON.dump({
        "types" => [],
        "source" => "",
        "author" => "tst_generate Benchmark",
        "license" => "Apache 2.0",
        "version" => "1.0.0",
        "description" => "Qualified variable lookup benchmark module 1",
        "summary" => "Just this benchmark module, you know?",
        "dependencies" => [],
      }, f)

    render(File.join(templates, 'module', 'params.pp.erb'),
           File.join(manifests, 'params.pp'),
           :name => module_name)

    render(File.join(templates, 'module', 'badclass.pp.erb'),
           File.join(manifests, 'badclass.pp'),
           :size => @size)

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
