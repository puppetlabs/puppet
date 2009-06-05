require 'puppet/util/autoload'
require 'puppet/parser/scope'

module Puppet::Parser
module Functions
    # A module for managing parser functions.  Each specified function
    # becomes an instance method on the Scope class.

    @functions = {}

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

    # Remove a function added by newfunction
    def self.rmfunction(name)
        name = symbolize(name)

        unless @functions.include? name
            raise Puppet::DevError, "Function %s is not defined" % name
        end

        @functions.delete(name)

        fname = "function_" + name.to_s
        Puppet::Parser::Scope.send(:remove_method, fname)
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
            #ret += "%s\n%s\n" % [name, hash[:type]]
            ret += "%s\n%s\n" % [name, "-" * name.to_s.length]
            if hash[:doc]
                ret += Puppet::Util::Docs.scrub(hash[:doc])
            else
                ret += "Undocumented.\n"
            end

            ret += "\n\n- **Type**: %s\n\n" % hash[:type]
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
            when :statement; return false
            when :rvalue; return true
            end
        else
            return false
        end
    end

    # Runs a newfunction to create a function for each of the log levels

    Puppet::Util::Log.levels.each do |level|
        newfunction(level, :doc => "Log a message on the server at level
        #{level.to_s}.") do |vals|
            send(level, vals.join(" "))
        end
    end

end
end
