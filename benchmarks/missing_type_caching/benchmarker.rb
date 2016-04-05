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
    Puppet[:always_retry_plugins] = false
  end

  def run(args=nil)
    env = Puppet.lookup(:environments).get('benchmarking')
    node = Puppet::Node.new("testing", :environment => env)
    Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'missing_type_caching')
    test_module_dir = File.join(environment, 'modules', 'testmodule',
                                'manifests')

    mkdir_p(File.join(environment, 'modules'))
    @size.times.each do |i|
      mkdir_p(File.join(environment, 'modules', "mymodule_#{i}", 'lib',
                        'puppet', 'type'))
      mkdir_p(File.join(environment, 'modules', "mymodule_#{i}", 'manifests'))
    end
    mkdir_p(File.join(environment, 'manifests'))

    mkdir_p(test_module_dir)


    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => @size)

    render(File.join(templates, 'module', 'testmodule.pp.erb'),
           File.join(test_module_dir, 'init.pp'),
           :name => "foo")

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
