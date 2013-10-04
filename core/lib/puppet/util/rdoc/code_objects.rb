require 'rdoc/code_objects'

module RDoc

  # This modules contains various class that are used to hold information
  # about the various Puppet language structures we found while parsing.
  #
  # Those will be mapped to their html counterparts which are defined in
  # PuppetGenerator.

  # PuppetTopLevel is a top level (usually a .pp/.rb file)
  class PuppetTopLevel < TopLevel
    attr_accessor :module_name, :global

    # will contain all plugins
    @@all_plugins = {}

    # contains all cutoms facts
    @@all_facts = {}

    def initialize(toplevel)
      super(toplevel.file_relative_name)
    end

    def self.all_plugins
      @@all_plugins.values
    end

    def self.all_facts
      @@all_facts.values
    end
  end

  # PuppetModule holds a Puppet Module
  # This is mapped to an HTMLPuppetModule
  # it leverage the RDoc (ruby) module infrastructure
  class PuppetModule < NormalModule
    attr_accessor :facts, :plugins

    def initialize(name,superclass=nil)
      @facts = []
      @plugins = []
      super(name,superclass)
    end

    def initialize_classes_and_modules
      super
      @nodes = {}
    end

    def add_plugin(plugin)
      add_to(@plugins, plugin)
    end

    def add_fact(fact)
      add_to(@facts, fact)
    end

    def add_node(name,superclass)
      cls = @nodes[name]
      unless cls
        cls = PuppetNode.new(name, superclass)
        @nodes[name] = cls if !@done_documenting
        cls.parent = self
        cls.section = @current_section
      end
      cls
    end

    def each_fact
      @facts.each {|c| yield c}
    end

    def each_plugin
      @plugins.each {|c| yield c}
    end

    def each_node
      @nodes.each {|c| yield c}
    end

    def nodes
      @nodes.values
    end
  end

  # PuppetClass holds a puppet class
  # It is mapped to a HTMLPuppetClass for display
  # It leverages RDoc (ruby) Class
  class PuppetClass < ClassModule
    attr_accessor :resource_list, :requires, :childs, :realizes

    def initialize(name, superclass)
      super(name,superclass)
      @resource_list = []
      @requires = []
      @realizes = []
      @childs = []
    end

    def add_resource(resource)
      add_to(@resource_list, resource)
    end

    def is_module?
      false
    end

    def superclass=(superclass)
      @superclass = superclass
    end

    # we're (ab)using the RDoc require system here.
    # we're adding a required Puppet class, overriding
    # the RDoc add_require method which sees ruby required files.
    def add_require(required)
      add_to(@requires, required)
    end

    def add_realize(realized)
      add_to(@realizes, realized)
    end

    def add_child(child)
      @childs << child
    end

    # Look up the given symbol. RDoc only looks for class1::class2.method
    # or class1::class2#method. Since our definitions are mapped to RDoc methods
    # but are written class1::class2::define we need to perform the lookup by
    # ourselves.
    def find_symbol(symbol, method=nil)
      result = super
      if not result and symbol =~ /::/
        modules = symbol.split(/::/)
        unless modules.empty?
          module_name = modules.shift
          result = find_module_named(module_name)
          if result
            last_name = ""
            previous = nil
            modules.each do |module_name|
              previous = result
              last_name = module_name
              result = result.find_module_named(module_name)
              break unless result
            end
            unless result
              result = previous
              method = last_name
            end
          end
        end
        if result && method
          if !result.respond_to?(:find_local_symbol)
            p result.name
            p method
            fail
          end
          result = result.find_local_symbol(method)
        end
      end
      result
    end

  end

  # PuppetNode holds a puppet node
  # It is mapped to a HTMLPuppetNode for display
  # A node is just a variation of a class
  class PuppetNode < PuppetClass
    def initialize(name, superclass)
      super(name,superclass)
    end

    def is_module?
      false
    end
  end

  # Plugin holds a native puppet plugin (function,type...)
  # It is mapped to a HTMLPuppetPlugin for display
  class Plugin < Context
    attr_accessor :name, :type

    def initialize(name, type)
      super()
      @name = name
      @type = type
      @comment = ""
    end

    def <=>(other)
      @name <=> other.name
    end

    def full_name
      @name
    end

    def http_url(prefix)
      path = full_name.split("::")
      File.join(prefix, *path) + ".html"
    end

    def is_fact?
      false
    end

    def to_s
      res = self.class.name + ": #{@name} (#{@type})\n"
      res << @comment.to_s
      res
    end
  end

  # Fact holds a custom fact
  # It is mapped to a HTMLPuppetPlugin for display
  class Fact < Context
    attr_accessor :name, :confine

    def initialize(name, confine)
      super()
      @name = name
      @confine = confine
      @comment = ""
    end

    def <=>(other)
      @name <=> other.name
    end

    def is_fact?
      true
    end

    def full_name
      @name
    end

    def to_s
      res = self.class.name + ": #{@name}\n"
      res << @comment.to_s
      res
    end
  end

  # PuppetResource holds a puppet resource
  # It is mapped to a HTMLPuppetResource for display
  # A resource is defined by its "normal" form Type[title]
  class PuppetResource < CodeObject
    attr_accessor :type, :title, :params

    def initialize(type, title, comment, params)
      super()
      @type = type
      @title = title
      @comment = comment
      @params = params
    end

    def <=>(other)
      full_name <=> other.full_name
    end

    def full_name
      @type + "[#{@title}]"
    end

    def name
      full_name
    end

    def to_s
      res = @type + "[#{@title}]\n"
      res << @comment.to_s
      res
    end
  end
end
