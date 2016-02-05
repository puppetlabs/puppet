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
    @parser  = Puppet::Pops::Parser::EvaluatingParser.new
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = @compiler.topscope

    # Perform a portion of what a compile does (just enough to evaluate the site.pp logic)
    @compiler.catalog.environment_instance = @compiler.environment
    @compiler.send(:evaluate_main)

    # Then pretend we are running as part of a compilation
    Puppet.push_context(@compiler.context_overrides, "Benchmark masquerading as compiler configured context")
  end

  def run(args = {})
    details = args[:detail] || 'all'
    measurements = []
    @micro_benchmarks.each do |name, source|
      # skip if all but the wanted if a single benchmark is wanted
      next unless details == 'all' || match = details.match(/#{name}(?:[\._\s](parse|eval))?$/)
      # if name ends with .parse or .eval only do that part, else do both parts
      ending = match ? match[1] : nil # parse, eval or nil ending
      unless ending == 'eval'
        measurements << Benchmark.measure("#{name} parse") do
          1..@parsecount.times { @parser.parse_string(source, name) }
        end
      end
      unless ending == 'parse'
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
              @scope.pop_ephemerals(scope_memo)
            end
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

    # Generate one module with a 3x function and a 4x function (namespaces)
    module_name = "module1"
    module_base = File.join(environment, 'modules', module_name)
    manifests = File.join(module_base, 'manifests')
    mkdir_p(manifests)
    functions_3x = File.join(module_base, 'lib', 'puppet', 'parser', 'functions')
    functions_4x = File.join(module_base, 'lib', 'puppet', 'functions')
    mkdir_p(functions_3x)
    mkdir_p(functions_4x)

    File.open(File.join(module_base, 'metadata.json'), 'w') do |f|
      JSON.dump({
        "types" => [],
        "source" => "",
        "author" => "Evaluations Benchmark",
        "license" => "Apache 2.0",
        "version" => "1.0.0",
        "description" => "Evaluations Benchmark module 1",
        "summary" => "Module with supporting logic for evaluations benchmark",
        "dependencies" => [],
      }, f)
    end

    render(File.join(templates, 'module', 'init.pp.erb'),
           File.join(manifests, 'init.pp'),
           :name => module_name)

    render(File.join(templates, 'module', 'func3.rb.erb'),
           File.join(functions_3x, 'func3.rb'),
           :name => module_name)

    # namespaced function
    mkdir_p(File.join(functions_4x, module_name))
    render(File.join(templates, 'module', 'module1_func4.rb.erb'),
           File.join(functions_4x, module_name, 'func4.rb'),
           :name => module_name)

    # non namespaced
    render(File.join(templates, 'module', 'func4.rb.erb'),
           File.join(functions_4x, 'func4.rb'),
           :name => module_name)
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end

end
