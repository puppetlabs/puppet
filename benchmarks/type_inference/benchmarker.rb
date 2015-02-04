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
  end

  def run(args=nil)
    unless @initialized
      require 'puppet'
      config = File.join(@target, 'puppet.conf')
      Puppet.initialize_settings(['--config', config])
      @initialized = true
    end
    env = Puppet.lookup(:environments).get('benchmarking')
    node = Puppet::Node.new("testing", :environment => env)
    # Mimic what apply does (or the benchmark will in part run for the *root* environment)
    Puppet.push_context({:current_environment => env},'current env for benchmark')
    Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'type_inference')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(
        File.join(templates, 'site.pp.erb'),
        File.join(environment, 'manifests', 'site.pp'),
        :size => @size)

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
