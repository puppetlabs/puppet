# Grr
require 'puppet/autoload'
require 'puppet/parser/scope'

module Puppet::Parser
module Functions
    # A module for managing parser functions.  Each specified function
    # becomes an instance method on the Scope class.

    class << self
        include Puppet::Util
    end

    # Create a new function type.
    def self.newfunction(name, ftype = :statement, &block)
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

        unless ftype == :statement or ftype == :rvalue
            raise Puppet::DevError, "Invalid statement type %s" % ftype.inspect
        end

        fname = "function_" + name.to_s
        Puppet::Parser::Scope.send(:define_method, fname, &block)

        # Someday we'll support specifying an arity, but for now, nope
        #@functions[name] = {:arity => arity, :type => ftype}
        @functions[name] = {:type => ftype, :name => fname}
    end

    # Determine if a given name is a function
    def self.function(name)
        name = symbolize(name)

        unless defined? @autoloader
            @autoloader = Puppet::Autoload.new(self,
                "puppet/parser/functions",
                :wrap => false
            )
        end

        unless @functions.include? name
            @autoloader.load(name)
        end

        if @functions.include? name
            return @functions[name][:name]
        else
            return false
        end
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
    newfunction(:include) do |vals|
        vals.each do |val|
            if objecttype = lookuptype(val)
                # It's a defined type, so set it into the scope so it can
                # be evaluated.
                setobject(
                    :type => val,
                    :arguments => {}
                )
            else
                raise Puppet::ParseError, "Unknown class %s" % val
            end
        end
    end

    # Tag the current scope with each passed name
    newfunction(:tag) do |vals|
        vals.each do |val|
            # Some hackery, because the tags are stored by object id
            # for singletonness.
            self.setclass(val.object_id, val)
        end

        # Also add them as tags
        self.tag(*vals)
    end

    # Test whether a given tag is set.  This functions as a big OR -- if any of the
    # specified tags are unset, we return false.
    newfunction(:tagged, :rvalue) do |vals|
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
    newfunction(:defined, :rvalue) do |vals|
        retval = true

        vals.each do |val|
            unless builtintype?(val) or lookuptype(val)
                retval = false
                break
            end
        end

        return retval
    end

    newfunction(:fail, :statement) do |vals|
        vals = vals.collect { |s| s.to_s }.join(" ") if vals.is_a? Array
        raise Puppet::ParseError, vals.to_s
    end

    newfunction(:template, :rvalue) do |vals|
        require 'erb'

        vals.collect do |file|
            # Use a wrapper, so the template can't get access to the full
            # Scope object.
            debug "Retrieving template %s" % file
            wrapper = Puppet::Parser::Scope::TemplateWrapper.new(self, file)

            begin
                wrapper.result()
            rescue => detail
                raise Puppet::ParseError,
                    "Failed to parse template %s: %s" %
                        [file, detail]
            end
        end.join("")
    end

    newfunction(:import, :statement) do |vals|
        result = AST::ASTArray.new({})

        files = []

        # Collect all of our files
        vals.each do |pat|
            # We can't interpolate at this point since we don't have any 
            # scopes set up. Warn the user if they use a variable reference
            tmp = nil
            if pat =~ /[*{}\[\]?\\]/
                tmp = Puppet::Parser::Parser.glob(pat)
            else
                tmp = Puppet::Parser::Parser.find(pat)
                if tmp
                    tmp = [tmp]
                else
                    tmp = []
                end
            end

            if tmp.size == 0
                raise Puppet::ImportError.new("No file(s) found for import " + 
                                                  "of '#{pat}'")
            end

            files += tmp
        end

        files.each do |file|
            parser = Puppet::Parser::Parser.new()
            debug("importing '%s'" % file)

            unless file =~ /^#{File::SEPARATOR}/
                file = File.join(dir, file)
            end
            begin
                parser.file = file
            rescue Puppet::ImportError
                Puppet.warning(
                    "Importing %s would result in an import loop" %
                        File.join(file)
                )
                next
            end
            # push the results into the main result array
            # We always return an array when we parse.
            parser.parse.each do |child|
                result.push child
            end
        end

        # Now that we have the entire result, evaluate it, since it's code
        return result.safeevaluate(:scope => self)
    end
end
end

# $Id$
