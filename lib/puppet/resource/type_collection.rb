require 'puppet/parser/type_loader'
require 'puppet/util/file_watcher'
require 'puppet/util/warnings'

class Puppet::Resource::TypeCollection
  attr_reader :environment
  attr_accessor :parse_failed

  include Puppet::Util::Warnings

  def clear
    @hostclasses.clear
    @definitions.clear
    @nodes.clear
    @notfound.clear
  end

  def initialize(env)
    @environment = env
    @hostclasses = {}
    @definitions = {}
    @nodes = {}
    @notfound = {}

    # So we can keep a list and match the first-defined regex
    @node_list = []
  end

  def import_ast(ast, modname)
    ast.instantiate(modname).each do |instance|
      add(instance)
    end
  end

  def inspect
    "TypeCollection" + { :hostclasses => @hostclasses.keys, :definitions => @definitions.keys, :nodes => @nodes.keys }.inspect
  end

  def <<(thing)
    add(thing)
    self
  end

  def add(instance)
    if instance.type == :hostclass and other = @hostclasses[instance.name] and other.type == :hostclass
      other.merge(instance)
      return other
    end
    method = "add_#{instance.type}"
    send(method, instance)
    instance.resource_type_collection = self
    instance
  end

  def add_hostclass(instance)
    dupe_check(instance, @hostclasses) { |dupe| "Class '#{instance.name}' is already defined#{dupe.error_context}; cannot redefine" }
    dupe_check(instance, @definitions) { |dupe| "Definition '#{instance.name}' is already defined#{dupe.error_context}; cannot be redefined as a class" }

    @hostclasses[instance.name] = instance
    instance
  end

  def hostclass(name)
    @hostclasses[munge_name(name)]
  end

  def add_node(instance)
    dupe_check(instance, @nodes) { |dupe| "Node '#{instance.name}' is already defined#{dupe.error_context}; cannot redefine" }

    @node_list << instance
    @nodes[instance.name] = instance
    instance
  end

  def loader
    @loader ||= Puppet::Parser::TypeLoader.new(environment)
  end

  def node(name)
    name = munge_name(name)

    if node = @nodes[name]
      return node
    end

    @node_list.each do |n|
      next unless n.name_is_regex?
      return n if n.match(name)
    end
    nil
  end

  def node_exists?(name)
    @nodes[munge_name(name)]
  end

  def nodes?
    @nodes.length > 0
  end

  def add_definition(instance)
    dupe_check(instance, @hostclasses) { |dupe| "'#{instance.name}' is already defined#{dupe.error_context} as a class; cannot redefine as a definition" }
    dupe_check(instance, @definitions) { |dupe| "Definition '#{instance.name}' is already defined#{dupe.error_context}; cannot be redefined" }
    @definitions[instance.name] = instance
  end

  def definition(name)
    @definitions[munge_name(name)]
  end

  def find_node(name)
    @nodes[munge_name(name)]
  end

  def find_hostclass(name)
    find_or_load(name, :hostclass)
  end

  def find_definition(name)
    find_or_load(name, :definition)
  end

  [:hostclasses, :nodes, :definitions].each do |m|
    define_method(m) do
      instance_variable_get("@#{m}").dup
    end
  end

  def parse_failed?
    @parse_failed
  end

  def version
    if !defined?(@version)
      if environment.config_version.nil? || environment.config_version == ""
        @version = Time.now.to_i
      else
        @version = Puppet::Util::Execution.execute([environment.config_version]).strip
      end
    end

    @version
  rescue Puppet::ExecutionFailure => e
    raise Puppet::ParseError, "Execution of config_version command `#{environment.config_version}` failed: #{e.message}", e.backtrace
  end

  private

  COLON_COLON = "::".freeze

  # Resolve namespaces and find the given object.  Autoload it if
  # necessary.
  def find_or_load(name, type)
    # Name is always absolute, but may start with :: which must be removed
    fqname = (name[0,2] == COLON_COLON ? name[2..-1] : name)

    result = send(type, fqname)
    unless result
      if @notfound[ fqname ] && Puppet[ :ignoremissingtypes ]
        # do not try to autoload if we already tried and it wasn't conclusive
        # as this is a time consuming operation. Warn the user.
        # Check first if debugging is on since the call to debug_once is expensive
        if Puppet[:debug]
          debug_once "Not attempting to load #{type} #{fqname} as this object was missing during a prior compilation"
        end
      else
        result = loader.try_load_fqname(type, fqname)
        @notfound[ fqname ] = result.nil?
      end
    end
    result
  end

  def munge_name(name)
    name.to_s.downcase
  end

  def dupe_check(instance, hash)
    return unless dupe = hash[instance.name]
    message = yield dupe
    instance.fail Puppet::ParseError, message
  end
end
