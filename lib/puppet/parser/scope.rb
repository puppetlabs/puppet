#!/usr/local/bin/ruby -w

# $Id$

# the interpreter
#
# this builds our virtual pinball machine, into which we'll place our host-specific
# information and out of which we'll receive our host-specific configuration

require 'puppet/transportable'

module Puppet
    module Parser
        class ScopeError < RuntimeError
            attr_accessor :line, :file
        end
        #---------------------------------------------------------------
        class Scope

            attr_accessor :symtable, :objectable, :parent, :level, :interp
            attr_accessor :name, :type

            # i don't really know how to deal with a global scope yet, so
            # i'm leaving it disabled
            @@global = nil

            @@hosttable = {}
            @@settingtable = []
            @@declarative = true

            #------------------------------------------------------------
            def Scope.declarative
                return @@declarative
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def Scope.declarative=(val)
                @@declarative = val
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def Scope.global
                return @@global
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def child=(scope)
                @children.push(scope)
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def declarative
                return @@declarative
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def initialize(parent = nil, declarative = true)
                @parent = parent
                if @parent.nil?
                    @level = 1
                    @@declarative = declarative
                else
                    @parent.child = self
                    @level = @parent.level + 1
                    @interp = @parent.interp
                end

                @children = []

                @symtable = Hash.new(nil)
                @typetable = Hash.new(nil)

                # the defaultstable is a hash of hashes
                @defaultstable = Hash.new { |dhash,type|
                    dhash[type] = Hash.new(nil)
                }

                @objectable = Hash.new { |typehash,typekey|
                    #hash[key] = TransObject.new(key)
                    typehash[typekey] = Hash.new { |namehash, namekey|
                        #Puppet.debug("Creating iobject with name %s and type %s" %
                        #    [namekey,typekey])
                        namehash[namekey] = TransObject.new(namekey,typekey)
                        @children.push namehash[namekey]

                        # this has to be last, because the return value of the
                        # block is the actual hash
                        namehash[namekey]
                    }
                }
                @map = {
                    "variable" => @symtable,
                    "type" => @typetable,
                    "object" => @objectable,
                    "defaults" => @defaultstable
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # this method just abstracts the upwards-recursive nature of
            # name resolution
            # because different tables are different depths (e.g., flat, or
            # hash of hashes), we pass in a code snippet that gets passed
            # the table.  It is assumed that the code snippet already has
            # the name in it
            def lookup(type,sub)
                table = @map[type]
                if table.nil?
                    error = Puppet::ParseError.new(
                        "Could not retrieve %s table at level %s" % [type,self.level]
                    )
                    error.stack = caller
                    raise error
                end

                if sub.is_a?(Proc) and obj = sub.call(table)
                    return obj
                elsif table.include?(sub)
                    return table[sub]
                elsif ! @parent.nil?
                    return @parent.lookup(type,sub)
                else
                    return :undefined
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def lookuphost(name)
                if @@hosttable.include?(name)
                    return @@hosttable[name]
                else
                    return nil
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # collect all of the defaults set at any higher scopes
            # this is a different type of lookup because it's additive --
            # it collects all of the defaults, with defaults in closer scopes
            # overriding those in later scopes
            def lookupdefaults(type)
                values = {}
                # first collect the values from the parents
                unless @parent.nil?
                    @parent.lookupdefaults(type).each { |var,value|
                        values[var] = value
                    }
                end

                # then override them with any current values
                # this should probably be done differently
                if @defaultstable.include?(type)
                    @defaultstable[type].each { |var,value|
                        values[var] = value
                    }
                end
                Puppet.debug "Got defaults for %s: %s" %
                    [type,values.inspect]
                return values
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def lookuptype(name)
                Puppet.debug "Looking up type %s" % name
                value = self.lookup("type",name)
                if value == :undefined
                    return nil
                else
                    return value
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # slightly different, because we're looking through a hash of hashes
            def lookupobject(name,type)
                Puppet.debug "Looking up object %s of type %s" % [name, type]
                sub = proc { |table|
                    if table.include?(type)
                        if type[type].include?(name)
                            type[type][name]
                        end
                    else
                        nil
                    end
                }
                value = self.lookup("object",sub)
                if value == :undefined
                    return nil
                else
                    return value
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def lookupvar(name)
                Puppet.debug "Looking up variable %s" % name
                value = self.lookup("variable", name)
                if value == :undefined
                    error = Puppet::ParseError.new(
                        "Undefined variable '%s'" % name
                    )
                    error.stack = caller
                    raise error
                else
                    #Puppet.debug "Value of '%s' is '%s'" % [name,value]
                    return value
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def newscope
                Puppet.debug "Creating new scope, level %s" % [self.level + 1]
                return Puppet::Parser::Scope.new(self)
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def setdefaults(type,params)
                table = @defaultstable[type]

                # if we got a single param, it'll be in its own array
                unless params[0].is_a?(Array)
                    params = [params]
                end

                params.each { |ary|
                    Puppet.debug "Default for %s is %s => %s" %
                        [type,ary[0].inspect,ary[1].inspect]
                    if @@declarative
                        if table.include?(ary[0])
                            error = Puppet::ParseError.new(
                                "Default already defined for %s { %s }" %
                                    [type,ary[0]]
                            )
                            error.stack = caller
                            raise error
                        end
                    else
                        if table.include?(ary[0])
                            # we should maybe allow this warning to be turned off...
                            Puppet.warning "Replacing default for %s { %s }" %
                                [type,ary[0]]
                        end
                    end
                    table[ary[0]] = ary[1]
                }
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def sethost(name,host)
                @@hosttable[name] = host
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def settype(name,ltype)
                @typetable[name] = ltype
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # when we have an 'eval' function, we should do that instead
            # for now, we only support variables in strings
            def strinterp(string)
                newstring = string.dup
                regex = Regexp.new('\$\{(\w+)\}|\$(\w+)')
                #Puppet.debug("interpreting '%s'" % string)
                while match = regex.match(newstring) do
                    if match[1]
                        newstring.sub!(regex,self.lookupvar(match[1]).to_s)
                    elsif match[2]
                        newstring.sub!(regex,self.lookupvar(match[2]).to_s)
                    else
                        raise Puppet::DevError, "Could not match variable in %s" %
                            newstring
                    end
                end
                #Puppet.debug("result is '%s'" % newstring)
                return newstring
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # this is kind of quirky, because it doesn't differentiate between
            # creating a new object and adding params to an existing object
            # it doesn't solve the real problem, though: cases like file recursion,
            # where one statement explicitly modifies an object, and another
            # statement modifies it because of recursion
            def setobject(type, name, params, file, line)
                obj = self.lookupobject(name,type)
                if obj == :undefined or obj.nil?
                    obj = @objectable[type][name]

                    # only set these if we've created the object, which is the
                    # most common case
                    obj.file = file
                    obj.line = line
                end

                # now add the params to whatever object we've found, whether
                # it was in a higher scope or we just created it
                # it will not be obvious where these parameters are from, that is,
                # which file they're in or whatever
                params.each { |var,value|
                    obj[var] = value
                }
                return obj
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            def setvar(name,value)
                Puppet.debug "Setting %s to '%s' at level %s" %
                    [name.inspect,value,self.level]
                if @@declarative and @symtable.include?(name)
                    error = Puppet::ParseError.new(
                        "Cannot reassign variable %s" % name
                    )
                    error.stack = caller
                    raise error
                else
                    if @symtable.include?(name)
                        Puppet.warning "Reassigning %s to %s" % [name,value]
                    end
                    @symtable[name] = value
                end
            end
            #------------------------------------------------------------

            #------------------------------------------------------------
            # I'm pretty sure this method could be obviated, but it doesn't
            # really seem worth it
            def to_trans
                Puppet.debug "Translating scope %s at level %s" %
                    [self.object_id,self.level]

                results = []
                
                @children.each { |child|
                    if child.is_a?(Scope)
                        cresult = child.to_trans
                        Puppet.debug "Got %s from scope %s" %
                            [cresult.class,child.object_id]

                        # get rid of the arrayness
                        unless cresult.is_a?(TransBucket)
                            cresult.each { |result|
                                results.push(result)
                            }
                        else
                            results.push(cresult)
                        end
                    elsif child.is_a?(TransObject)
                        results.push(child)
                    else
                        error = Puppet::DevError.new(
                            "Puppet::Parse::Scope cannot handle objects of type %s" %
                                child.class
                        )
                        error.stack = caller
                        raise error
                    end
                }
                results = results.reject { |child|
                    # if a scope didn't result in any objects, we get some nils
                    # just get rid of them
                    child.nil?
                }

                # if we have a name and type, then make a TransBucket, which
                # becomes a component
                # else, just stack all of the objects into the current bucket
                if defined? @name
                    bucket = TransBucket.new
                    bucket.name = @name

                    # it'd be nice not to have to do this...
                    results.each { |result|
                        #Puppet.debug "Result type is %s" % result.class
                        bucket.push(result)
                    }
                    if defined? @type
                        bucket.type = @type
                    else
                        error = Puppet::ParseError.new(
                            "No type for scope %s" % @name
                        )
                        error.stack = caller
                        raise error
                    end
                    Puppet.debug "TransBucket with name %s and type %s in scope %s" %
                        [@name,@type,self.object_id]

                    # now find metaparams
                    @symtable.each { |var,value|
                        if Puppet::Type.metaparam?(var.intern)
                            #Puppet.debug("Adding metaparam %s" % var)
                            bucket.param(var,value)
                        else
                            #Puppet.debug("%s is not a metaparam" % var)
                        end
                    }
                    #Puppet.debug "Returning bucket %s from scope %s" %
                    #    [bucket.name,self.object_id]
                    return bucket
                else
                    #Puppet.debug "nameless scope; just returning a list"
                    return results
                end
            end
            #------------------------------------------------------------
        end
        #---------------------------------------------------------------
    end
end
