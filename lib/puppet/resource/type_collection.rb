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
    @watched_files.clear
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

    @watched_files = Puppet::Util::FileWatcher.new
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

    @node_list.each do |node|
      next unless node.name_is_regex?
      return node if node.match(name)
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

  def find_node(namespaces, name)
    @nodes[munge_name(name)]
  end

  def find_hostclass(namespaces, name, options = {})
    find_or_load(namespaces, name, :hostclass, options)
  end

  def find_definition(namespaces, name)
    find_or_load(namespaces, name, :definition)
  end

  [:hostclasses, :nodes, :definitions].each do |m|
    define_method(m) do
      instance_variable_get("@#{m}").dup
    end
  end

  def require_reparse?
    @parse_failed || stale?
  end

  def stale?
    @watched_files.changed?
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

  def watch_file(filename)
    @watched_files.watch(filename)
  end

  def watching_file?(filename)
    @watched_files.watching?(filename)
  end

  private

  # Return a list of all possible fully-qualified names that might be
  # meant by the given name, in the context of namespaces.
  def resolve_namespaces(namespaces, name)
    name      = name.downcase
    if name =~ /^::/
      # name is explicitly fully qualified, so just return it, sans
      # initial "::".
      return [name.sub(/^::/, '')]
    end
    if name == ""
      # The name "" has special meaning--it always refers to a "main"
      # hostclass which contains all toplevel resources.
      return [""]
    end

    namespaces = [namespaces] unless namespaces.is_a?(Array)
    namespaces = namespaces.collect { |ns| ns.downcase }

    result = []
    namespaces.each do |namespace|
      ary = namespace.split("::")

      # Search each namespace nesting in innermost-to-outermost order.
      while ary.length > 0
        result << "#{ary.join("::")}::#{name}"
        ary.pop
      end

      # Finally, search the toplevel namespace.
      result << name
    end

    return result.uniq
  end

  # Resolve namespaces and find the given object.  Autoload it if
  # necessary.
  def find_or_load(namespaces, name, type, options = {})
    searchspace = options[:assume_fqname] ? [name].flatten : resolve_namespaces(namespaces, name)
    searchspace.each do |fqname|
      result = send(type, fqname)
      unless result
        if @notfound[fqname] and Puppet[:ignoremissingtypes]
          # do not try to autoload if we already tried and it wasn't conclusive
          # as this is a time consuming operation. Warn the user.
          debug_once "Not attempting to load #{type} #{fqname} as this object was missing during a prior compilation"
        else
          result = loader.try_load_fqname(type, fqname)
          @notfound[fqname] = result.nil?
        end
      end
      return result if result
    end

    return nil
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
