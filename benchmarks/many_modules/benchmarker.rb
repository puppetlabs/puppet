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
    templates = File.join('benchmarks', 'many_modules')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => @size)

    @size.times do |i|
      module_name = "module#{i}"
      module_base = File.join(environment, 'modules', module_name)
      manifests = File.join(module_base, 'manifests')
      locales = File.join(module_base, 'locales')

      mkdir_p(manifests)
      mkdir_p(locales)

      File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
        JSON.dump({
          "name" => "module#{i}",
          "types" => [],
          "source" => "",
          "author" => "ManyModules Benchmark",
          "license" => "Apache 2.0",
          "version" => "1.0.0",
          "description" => "Many Modules benchmark module #{i}",
          "summary" => "Just this benchmark module, you know?",
          "dependencies" => [],
        }, f)
      end

      File.open(File.join(locales, 'config.yaml'), 'w') do |f|
        f.puts(
          {"gettext"=>
            {"project_name"=>"module#{i}",
            "package_name"=>"module#{i}",
            "default_locale"=>"en",
            "bugs_address"=>"docs@puppet.com",
            "copyright_holder"=>"Puppet, Inc.",
            "comments_tag"=>"TRANSLATOR",
            "source_files"=>["./lib/**/*.rb"]}}.to_yaml
          )
      end

      render(File.join(templates, 'module', 'init.pp.erb'),
             File.join(manifests, 'init.pp'),
             :name => module_name)

      render(File.join(templates, 'module', 'internal.pp.erb'),
             File.join(manifests, 'internal.pp'),
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
