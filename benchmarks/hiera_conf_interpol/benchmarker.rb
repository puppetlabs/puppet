require 'fileutils'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = size > 100 ? size : 100
  end

  def setup
    require 'puppet'
    @config = File.join(@target, 'puppet.conf')
    Puppet.initialize_settings(['--config', @config])
    envs = Puppet.lookup(:environments)
    @node = Puppet::Node.new('testing', :environment => envs.get('benchmarking'))
  end

  def run(args=nil)
    @compiler = Puppet::Parser::Compiler.new(@node)
    @compiler.compile do |catalog|
      scope = @compiler.topscope
      50.times { |index| scope["d#{index}"] = "dir_#{index}" }
      @size.times do
        100.times do |index|
          invocation = Puppet::Pops::Lookup::Invocation.new(scope)
          Puppet::Pops::Lookup.lookup('a', nil, nil, true, nil, invocation)
        end
      end
      catalog
    end
  end

  def generate
    env_dir = File.join(@target, 'environments', 'benchmarking')
    hiera_yaml = File.join(@target, 'hiera.yaml')
    datadir = File.join(@target, 'data')

    mkdir_p(env_dir)
    File.open(hiera_yaml, 'w') do |f|
      f.puts('version: 5')
      f.puts('hierarchy:')
      50.times do |index|
        5.times do |repeat|
          f.puts("  - name: Entry_#{index}_#{repeat}")
          f.puts("    path: \"%{::d#{index}}/data_#{repeat}\"")
        end
      end
    end

    dir_0_dir = File.join(datadir, 'dir_0')
    mkdir_p(dir_0_dir)

    data_0_yaml = File.join(dir_0_dir, 'data_0.yaml')
    File.open(data_0_yaml, 'w') do |f|
      f.puts('a: value a')
    end

    templates = File.join('benchmarks', 'hiera_conf_interpol')

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
