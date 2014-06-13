require 'erb'
require 'ostruct'
require 'fileutils'
require 'json'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = size
    @micro_benchmarks = {}
    @parsecount = 100
    @evalcount = 100
  end

  def setup
    require 'puppet'
    require 'puppet/pops'
    config = File.join(@target, 'puppet.conf')
    Puppet.initialize_settings(['--config', config])
    manifests = File.join('benchmarks', 'evaluations', 'manifests')
    Dir.foreach(manifests) do |f|
      if f =~ /^(.*)\.pp$/
        @micro_benchmarks[$1] = File.read(File.join(manifests, f))
      end
    end
    # Run / Evaluate the common puppet logic
    @env = Puppet.lookup(:environments).get('benchmarking')
    @node = Puppet::Node.new("testing", :environment => @env)
    @parser  = Puppet::Pops::Parser::EvaluatingParser::Transitional.new
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = @compiler.topscope

    # Perform a portion of what a compile does (just enough to evaluate the site.pp logic)
    @compiler.catalog.environment_instance = @compiler.environment
    @compiler.send(:evaluate_main)
  end

  def run
    measurements = []
    @micro_benchmarks.each do |name, source|
      measurements << Benchmark.measure("#{name} parse") do
        1..@parsecount.times { @parser.parse_string(source, name) }
      end
      model = @parser.parse_string(source, name)
      measurements << Benchmark.measure("#{name} eval") do
        1..@evalcount.times do
          begin
            # Run each in a local scope
            scope_memo = @scope.ephemeral_level
            @scope.new_ephemeral(true)
            @parser.evaluate(@scope, model)
          ensure
            # Toss the created local scope
            @scope.unset_ephemeral_var(scope_memo)
          end
        end
      end
    end
    measurements
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'evaluations')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(File.join(templates, 'site.pp.erb'),
    File.join(environment, 'manifests', 'site.pp'),{})

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
