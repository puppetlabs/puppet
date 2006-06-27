# Grr
require 'puppet/parser/scope'

module Puppet::Parser
module Functions
    # A module for managing parser functions.  Each specified function
    # becomes an instance method on the Scope class.

    # Create a new function type.
    def self.newfunction(name, ftype = :statement, &block)
        @functions ||= {}
        name = name.intern if name.is_a? String

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
        name = name.intern if name.is_a? String

        if @functions.include? name
            return @functions[name][:name]
        else
            return false
        end
    end

    # Determine if a given function returns a value or not.
    def self.rvalue?(name)
        name = name.intern if name.is_a? String

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
        vals = vals.join(" ") if vals.is_a? Array
        raise Puppet::ParseError, vals
    end
end
end

# $Id$
