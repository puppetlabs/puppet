require 'erb'
require 'ostruct'
require 'fileutils'
require 'json'

# For memory debugging - if the core_ext is not loaded, things break inside mass
# require 'mass'
require 'objspace'

# Only runs for Ruby > 2.1.0, and must do this early since ObjectSpace.trace_object_allocations_start must be called
# as early as possible.
#
RUBYVER_ARRAY = RUBY_VERSION.split(".").collect {|s| s.to_i }
RUBYVER = (RUBYVER_ARRAY[0] << 16 | RUBYVER_ARRAY[1] << 8 | RUBYVER_ARRAY[2])
if RUBYVER < (2 << 16 | 1 << 8 | 0)
  puts "catalog_memory requires Ruby version >= 2.1.0 to run. Skipping"
  exit(0)
end

ObjectSpace.trace_object_allocations_start

class Benchmarker
  include FileUtils


  def initialize(target, size)
    @target = target
    @size = size
    @@first_counts = nil
    @@first_refs = nil
    @@count = 0
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
    @@count += 1
    env = Puppet.lookup(:environments).get('benchmarking')
    node = Puppet::Node.new("testing", :environment => env)
    # Mimic what apply does (or the benchmark will in part run for the *root* environment)
    Puppet.push_context({:current_environment => env},'current env for benchmark')
    Puppet::Resource::Catalog.indirection.find("testing", :use_node => node)
    Puppet.pop_context
    GC.start
    sleep(2)
    counted = ObjectSpace.count_objects({})
    if @@first_counts && @@count == 10
      diff = @@first_counts.merge(counted) {|k, base_v, new_v| new_v - base_v }
      puts "Count of objects TOTAL = #{diff[:TOTAL]}, FREE = #{diff[:FREE]}, T_OBJECT = #{diff[:T_OBJECT]}, T_CLASS = #{diff[:T_CLASS]}"
      changed = diff.reject {|k,v| v == 0}
      puts "Number of changed classes = #{changed}"
      GC.start
      # Find references to leaked Objects
      leaked_instances = ObjectSpace.each_object.reduce([]) {|x, o| x << o.object_id; x } - @@first_refs
      File.open("diff.json", "w") do |f|
        leaked_instances.each do |id|
          o = ObjectSpace._id2ref(id)
          f.write(ObjectSpace.dump(o)) if !o.nil?
        end
      end
      # Output information where bound objects where instantiated
      map_of_allocations = leaked_instances.reduce(Hash.new(0)) do |memo, x|
        o = ObjectSpace._id2ref(x)
        class_path = ObjectSpace.allocation_class_path(o)
        class_path = class_path.nil? ? ObjectSpace.allocation_sourcefile(o) : class_path
        if !class_path.nil?
          method = ObjectSpace.allocation_method_id(o)
          source_line = ObjectSpace.allocation_sourceline(o)
          memo["#{class_path}##{method}-#{source_line}"] += 1
        end
        memo
      end
      map_of_allocations.sort_by {|k, v| v}.reverse_each {|k,v| puts "#{v} #{k}" }
      # Dump the heap for further analysis
      GC.start
      ObjectSpace.dump_all(output: File.open('heap.json','w'))
    elsif @@count == 1
      # Set up baseline and output info for first run
      @@first_counts = counted
      @@first_refs = ObjectSpace.each_object.reduce([]) {|x, o| x << o.object_id; x }
      diff = @@first_counts
      puts "Count of objects TOTAL = #{diff[:TOTAL]}, FREE = #{diff[:FREE]}, T_OBJECT = #{diff[:T_OBJECT]}, T_CLASS = #{diff[:T_CLASS]}"
    end

  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'empty_catalog')

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
