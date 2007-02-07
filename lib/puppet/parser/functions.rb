# Grr
require 'puppet/util/autoload'
require 'puppet/parser/scope'

module Puppet::Parser
module Functions
    # A module for managing parser functions.  Each specified function
    # becomes an instance method on the Scope class.

    class << self
        include Puppet::Util
    end

    def self.autoloader
        unless defined? @autoloader
            @autoloader = Puppet::Util::Autoload.new(self,
                "puppet/parser/functions",
                :wrap => false
            )
        end

        @autoloader
    end

    # Create a new function type.
    def self.newfunction(name, options = {}, &block)
        @functions ||= {}
        name = symbolize(name)

        if @functions.include? name
            raise Puppet::DevError, "Function %s already defined" % name
        end

        # We want to use a separate, hidden module, because we don't want
        # people to be able to call them directly.
        unless defined? FCollection
            eval("module FCollection; end")
        end

        ftype = options[:type] || :statement

        unless ftype == :statement or ftype == :rvalue
            raise Puppet::DevError, "Invalid statement type %s" % ftype.inspect
        end

        fname = "function_" + name.to_s
        Puppet::Parser::Scope.send(:define_method, fname, &block)

        # Someday we'll support specifying an arity, but for now, nope
        #@functions[name] = {:arity => arity, :type => ftype}
        @functions[name] = {:type => ftype, :name => fname}
        if options[:doc]
            @functions[name][:doc] = options[:doc]
        end
    end

    # Determine if a given name is a function
    def self.function(name)
        name = symbolize(name)

        unless @functions.include? name
            autoloader.load(name)
        end

        if @functions.include? name
            return @functions[name][:name]
        else
            return false
        end
    end

    def self.functiondocs
        autoloader.loadall

        ret = ""

        @functions.sort { |a,b| a[0].to_s <=> b[0].to_s }.each do |name, hash|
            ret += "* **%s** (*%s*)" % [name, hash[:type]]
            if hash[:doc]
                ret += ":  " + hash[:doc].gsub(/\n\s*/, ' ')
            else
                ret += ":  ``undocumented``"
            end
            ret += "\n\n"
        end

        return ret
    end

    def self.functions
        @functions.keys
    end

    # Determine if a given function returns a value or not.
    def self.rvalue?(name)
        name = symbolize(name)

        if @functions.include? name
            case @functions[name][:type]
            when :statement: return false
            when :rvalue: return true
            end
        else
            return false
        end
    end

    # Include the specified classes
    newfunction(:include, :doc => "Evaluate one or more classes.") do |vals|
        klasses = evalclasses(*vals)

        missing = vals.find_all do |klass|
            ! klass.include?(klass)
        end

        # Throw an error if we didn't evaluate all of the classes.
        if missing.length == 1
            self.fail Puppet::ParseError,
                "Could not find class %s" % missing
        elsif missing.length > 1
            self.fail Puppet::ParseError,
                "Could not find classes %s" % missing.join(", ")
        end
    end

    # Tag the current scope with each passed name
    newfunction(:tag, :doc => "Add the specified tags to the containing class
    or definition.  All contained objects will then acquire that tag, also.
    ") do |vals|
        self.tag(*vals)
    end

    # Test whether a given tag is set.  This functions as a big OR -- if any of the
    # specified tags are unset, we return false.
    newfunction(:tagged, :type => :rvalue, :doc => "A boolean function that
    tells you whether the current container is tagged with the specified tags.
    The tags are ANDed, so thta all of the specified tags must be included for
    the function to return true.") do |vals|
        classlist = self.classlist

        retval = true
        vals.each do |val|
            unless classlist.include?(val) or self.tags.include?(val)
                retval = false
                break
            end
        end

        return retval
    end

    # Test whether a given class or definition is defined
    newfunction(:defined, :type => :rvalue, :doc => "Determine whether a given
    type is defined, either as a native type or a defined type, or whether a resource has been
    specified.  If you are checking with a resource is defined, use the normal resource
    reference syntax, e.g., ``File['/etc/passwd']``.") do |vals|
        result = false
        vals.each do |val|
            case val
            when String:
                # For some reason, it doesn't want me to return from here.
                if Puppet::Type.type(val) or finddefine(val) or findclass(val)
                    result = true
                    break
                end
            when Puppet::Parser::Resource::Reference:
                if findresource(val.to_s)
                    result = true
                    break
                end
            else
                raise ArgumentError, "Invalid argument of type %s to 'defined'" % val.class
            end
        end
        result
    end

    newfunction(:fail, :doc => "Fail with a parse error.") do |vals|
        vals = vals.collect { |s| s.to_s }.join(" ") if vals.is_a? Array
        raise Puppet::ParseError, vals.to_s
    end

    # Runs a newfunction to create a function for each of the log levels
    Puppet::Util::Log.levels.each do |level|      
        newfunction(level, :doc => "Log a message on the server at level
        #{level.to_s}.") do |vals| 
            send(level, vals.join(" ")) 
        end 
    end

    newfunction(:template, :type => :rvalue, :doc => "Evaluate a template and
    return its value.  See [the templating docs](/trac/puppet/wiki/PuppetTemplating)
    for more information.  Note that if multiple templates are specified, their
    output is all concatenated and returned as the output of the function.") do |vals|
        require 'erb'

        vals.collect do |file|
            # Use a wrapper, so the template can't get access to the full
            # Scope object.
            debug "Retrieving template %s" % file
            wrapper = Puppet::Parser::TemplateWrapper.new(self, file)

            begin
                wrapper.result()
            rescue => detail
                raise Puppet::ParseError,
                    "Failed to parse template %s: %s" %
                        [file, detail]
            end
        end.join("")
    end

    # This is just syntactic sugar for a collection, although it will generally
    # be a good bit faster.
    newfunction(:realize, :doc => "Make a virtual object real.  This is useful
    when you want to know the name of the virtual object and don't want to
    bother with a full collection.  It is slightly faster than a collection,
    and, of course, is a bit shorter.  You must pass the object using a
    reference; e.g.: ``realize User[luke]``." ) do |vals|
        coll = Puppet::Parser::Collector.new(self, :nomatter, nil, nil, :virtual)
        vals = [vals] unless vals.is_a?(Array)
        coll.resources = vals

        newcollection(coll)
    end
end
end

# $Id$
