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
      scope['confdir'] = 'test'
      @size.times do
        100.times do |index|
          invocation = Puppet::Pops::Lookup::Invocation.new(scope)
          Puppet::Pops::Lookup.lookup("x#{index}", nil, nil, true, nil, invocation)
        end

        100.times do
          invocation = Puppet::Pops::Lookup::Invocation.new(scope)
          Puppet::Pops::Lookup.lookup("h1.h2.h3.k0", nil, nil, true, nil, invocation)
        end
      end
      catalog
    end
  end

  def generate
    # $codedir/
    #   environments/benchmarking/
    #   hiera.yaml
    #   data/
    #     test/data.yaml
    #     common.yaml
    #
    env_dir = File.join(@target, 'environments', 'benchmarking')
    hiera_yaml = File.join(@target, 'hiera.yaml')
    datadir = File.join(@target, 'data')
    datadir_test = File.join(datadir, 'test')
    test_data_yaml = File.join(datadir_test, 'data.yaml')
    common_yaml = File.join(datadir, 'common.yaml')

    mkdir_p(env_dir)
    mkdir_p(datadir_test)

    File.open(hiera_yaml, 'w') do |f|
      f.puts(<<-YAML)
---
version: 5
defaults:
  datadir: data
  data_hash: yaml_data
hierarchy:
  - name: Configured
    path: test/data.yaml
  - name: Common
    path: common.yaml
YAML
    end

    File.open(common_yaml, 'w') do |f|
      100.times do |index|
        f.puts("a#{index}: value a#{index}")
        f.puts("b#{index}: value b#{index}")
        f.puts("c#{index}: value c#{index}")
        f.puts("cbm#{index}: \"%{hiera('a#{index}')}, %{hiera('b#{index}')}, %{hiera('c#{index}')}\"")
      end
    end

    File.open(test_data_yaml, 'w') do |f|
      100.times { |index| f.puts("x#{index}: \"%{hiera('cbm#{index}')}\"")}

      f.puts(<<-YAML)
h1:
  h2:
    h3:
YAML
      100.times { |index| f.puts(<<-YAML) }
      k#{index}: v#{index}
YAML
    end

    templates = File.join('benchmarks', 'hiera_global_lookup')

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
