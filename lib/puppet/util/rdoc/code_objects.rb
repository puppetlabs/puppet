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
        attr_accessor :resource_list

        def initialize(name, superclass)
            super(name,superclass)
            @resource_list = []
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
            res = self.class.name + ": " + @name + " (" + @type + ")\n"
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
            res = self.class.name + ": " + @name + "\n"
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
            @type + "[" + @title + "]"
        end

        def name
            full_name
        end

        def to_s
            res = @type + "[" + @title + "]\n"
            res << @comment.to_s
            res
        end
    end
end
