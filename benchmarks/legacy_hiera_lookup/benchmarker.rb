require 'fileutils'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @hiera_yaml = File.join(target, 'hiera.yaml')
    @size = size > 100 ? size : 100
  end

  def setup
    require 'puppet'
    require 'hiera'
    @config = File.join(@target, 'puppet.conf')
    Puppet.initialize_settings(['--config', @config])
    Hiera.logger = 'noop'
    @hiera = ::Hiera.new(:config => @hiera_yaml)
  end

  def run(args=nil)
    @size.times do
      100.times do |index|
        @hiera.lookup("x#{index}", nil, { 'confdir' => 'test' })
      end
    end
  end

  def generate
    datadir = File.join(@target, 'data')
    datadir_test = File.join(datadir, 'test')
    test_data_yaml = File.join(datadir_test, 'data.yaml')
    common_yaml = File.join(datadir, 'common.yaml')

    mkdir_p(datadir)
    mkdir_p(datadir_test)

    File.open(@hiera_yaml, 'w') do |f|
      f.puts(<<-YAML)
---
:backends: yaml
:yaml:
   :datadir: #{datadir}
:hierarchy:
   - "%{confdir}/data"
   - common
:logger: noop
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
    end
  end
end
