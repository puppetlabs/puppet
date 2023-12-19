# frozen_string_literal: true
require_relative '../../puppet/parser/type_loader'
require_relative '../../puppet/util/file_watcher'
require_relative '../../puppet/util/warnings'
require_relative '../../puppet/concurrent/lock'

# @api private
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
    # always lock the environment before acquiring this lock
    @lock = Puppet::Concurrent::Lock.new

    # So we can keep a list and match the first-defined regex
    @node_list = []
  end

  def import_ast(ast, modname)
    ast.instantiate(modname).each do |instance|
      add(instance)
    end
  end

  def inspect
    "TypeCollection" + {
      :hostclasses => @hostclasses.keys,
      :definitions => @definitions.keys,
      :nodes => @nodes.keys
    }.inspect
  end

  # @api private
  def <<(thing)
    add(thing)
    self
  end

  def add(instance)
    # return a merged instance, or the given
    catch(:merged) {
      send("add_#{instance.type}", instance)
      instance.resource_type_collection = self
      instance
    }
  end

  def add_hostclass(instance)
    handle_hostclass_merge(instance)
    dupe_check(instance, @hostclasses) { |dupe| _("Class '%{klass}' is already defined%{error}; cannot redefine") % { klass: instance.name, error: dupe.error_context } }
    dupe_check(instance, @nodes)       { |dupe| _("Node '%{klass}' is already defined%{error}; cannot be redefined as a class") % { klass: instance.name, error: dupe.error_context } }
    dupe_check(instance, @definitions) { |dupe| _("Definition '%{klass}' is already defined%{error}; cannot be redefined as a class") % { klass: instance.name, error: dupe.error_context } }

    @hostclasses[instance.name] = instance
    instance
  end

  def handle_hostclass_merge(instance)
    # Only main class (named '') can be merged (for purpose of merging top-scopes).
    return instance unless instance.name == ''

    if instance.type == :hostclass && (other = @hostclasses[instance.name]) && other.type == :hostclass
      other.merge(instance)
      # throw is used to signal merge - avoids dupe checks and adding it to hostclasses
      throw :merged, other
    end
  end

  # Replaces the known settings with a new instance (that must be named 'settings').
  # This is primarily needed for testing purposes. Also see PUP-5954 as it makes 
  # it illegal to merge classes other than the '' (main) class. Prior to this change
  # settings where always merged rather than being defined from scratch for many testing scenarios
  # not having a complete side effect free setup for compilation.
  # 
  def replace_settings(instance)
    @hostclasses['settings'] = instance
  end

  def hostclass(name)
    @hostclasses[munge_name(name)]
  end

  def add_node(instance)
    dupe_check(instance, @nodes) { |dupe| _("Node '%{name}' is already defined%{error}; cannot redefine") % { name: instance.name, error: dupe.error_context } }
    dupe_check(instance, @hostclasses) { |dupe| _("Class '%{klass}' is already defined%{error}; cannot be redefined as a node") % { klass: instance.name, error: dupe.error_context } }

    @node_list << instance
    @nodes[instance.name] = instance
    instance
  end

  def loader
    @loader ||= Puppet::Parser::TypeLoader.new(environment)
  end

  def node(name)
    name = munge_name(name)

    node = @nodes[name]
    if node
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
    dupe_check(instance, @hostclasses) { |dupe| _("'%{name}' is already defined%{error} as a class; cannot redefine as a definition") % { name: instance.name, error: dupe.error_context } }
    dupe_check(instance, @definitions) { |dupe| _("Definition '%{name}' is already defined%{error}; cannot be redefined") % { name: instance.name, error: dupe.error_context } }

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

  # TODO: This implementation is wasteful as it creates a copy on each request
  #
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
        @version = Puppet::Util::Execution.execute([environment.config_version]).to_s.strip
      end
    end

    @version
  rescue Puppet::ExecutionFailure => e
    raise Puppet::ParseError, _("Execution of config_version command `%{cmd}` failed: %{message}") % { cmd: environment.config_version, message: e.message }, e.backtrace
  end

  private

  COLON_COLON = "::"

  # Resolve namespaces and find the given object.  Autoload it if
  # necessary.
  def find_or_load(name, type)
    # always lock the environment before locking the type collection
    @environment.lock.synchronize do
      @lock.synchronize do
        # Name is always absolute, but may start with :: which must be removed
        fqname = (name[0,2] == COLON_COLON ? name[2..-1] : name)

        result = send(type, fqname)
        unless result
          if @notfound[ fqname ] && Puppet[ :ignoremissingtypes ]
            # do not try to autoload if we already tried and it wasn't conclusive
            # as this is a time consuming operation. Warn the user.
            # Check first if debugging is on since the call to debug_once is expensive
            if Puppet[:debug]
              debug_once _("Not attempting to load %{type} %{fqname} as this object was missing during a prior compilation") % { type: type, fqname: fqname }
            end
          else
            fqname = munge_name(fqname)
            result = loader.try_load_fqname(type, fqname)
            @notfound[ fqname ] = result.nil?
          end
        end
        result
      end
    end
  end

  def munge_name(name)
    name.to_s.downcase
  end

  def dupe_check(instance, hash)
    dupe = hash[instance.name]
    return unless dupe

    message = yield dupe
    instance.fail Puppet::ParseError, message
  end

  def dupe_check_singleton(instance, set)
    return if set.empty?

    message = yield set[0]
    instance.fail Puppet::ParseError, message
  end
end
