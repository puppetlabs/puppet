# The scope class, which handles storing and retrieving variables and types and
# such.

require 'puppet/transportable'

module Puppet
    module Parser
        class Scope
            include Enumerable
            attr_accessor :parent, :level, :interp
            attr_accessor :name, :type

            # This is probably not all that good of an idea, but...
            # This way a parent can share its node table with all of its children.
            attr_writer :nodetable 

            # Whether we behave declaratively.  Note that it's a class variable,
            # so all scopes behave the same.
            @@declarative = true

            # Retrieve and set the declarative setting.
            def Scope.declarative
                return @@declarative
            end

            def Scope.declarative=(val)
                @@declarative = val
            end

            # Create a new child scope.
            def child=(scope)
                @children.push(scope)

                if defined? @nodetable
                    scope.nodetable = @nodetable
                else
                    raise Puppet::DevError, "No nodetable has been defined"
                end
            end

            # Test whether a given scope is declarative.  Even though it's
            # a global value, the calling objects don't need to know that.
            def declarative?
                @@declarative
            end

            # Remove a specific child.
            def delete(child)
                @children.delete(child)
            end

            # Verify that no nodescopes are hanging around.
            def nodeclean
                @children.find_all { |child|
                    if child.is_a?(Scope)
                        child.nodescope?
                    else
                        false
                    end
                }.each { |child|
                    @children.delete(child)
                }

                @children.each { |child|
                    if child.is_a?(Scope)
                        child.nodeclean
                    end
                }
            end

            # Is this scope associated with being a node?  The answer determines
            # whether we store class instances here
            def nodescope?
                @nodescope
            end

            def nodescope=(bool)
                @nodescope = bool
            end

            # Are we the top scope?
            def topscope?
                @level == 1
            end

            # Yield each child scope in turn
            def each
                @children.reject { |child|
                    yield child
                }
            end

            # Evaluate a specific node's code.  This method will normally be called
            # on the top-level scope, but it actually evaluates the node at the
            # appropriate scope.
            def evalnode(names, facts)
                scope = code = nil

                # Find a node that matches one of our names
                names.each { |node|
                    if hash = @nodetable[node]
                        code = hash[:node]
                        scope = hash[:scope]
                        break
                    end
                }

                # And fail if we don't find one.
                unless scope and code
                    raise Puppet::Error, "Could not find configuration for %s" %
                        names.join(" or ")
                end

                # First make sure there aren't any other node scopes lying around
                self.nodeclean

                # We need to do a little skullduggery here.  We want a
                # temporary scope, because we don't want this scope to
                # show up permanently in the scope tree -- otherwise we could
                # not evaluate the node multiple times.  We could conceivably
                # cache the results, but it's not worth it at this stage.

                # Note that we evaluate the node code with its containing
                # scope, not with the top scope.
                code.safeevaluate(scope, facts)

                # We don't need to worry about removing the Node code because
                # it will be removed during translation.

                # And now return the whole thing
                #return self.to_trans
                return self.to_trans
            end

            # Retrieve a specific node.  This is basically only used from within
            # 'findnode'.
            def node(name)
                @nodetable[name]
            end

            # Store a host in the site node table.
            def setnode(name,code)
                unless defined? @nodetable
                    raise Puppet::DevError, "No node table defined"
                end
                if @nodetable.include?(name)
                    raise Puppet::ParseError, "Host %s is already defined" % name
                else
                    #Puppet.warning "Setting node %s at level %s" % [name, @level]

                    # We have to store both the scope that's setting the node and
                    # the node itself, so that the node gets evaluated in the correct
                    # scope.
                    @nodetable[name] = {
                        :scope => self,
                        :node => code
                    }
                end
            end

            # Evaluate normally, with no node definitions
            def evaluate(objects, facts = {})
                facts.each { |var, value|
                    self.setvar(var, value)
                }

                objects.safeevaluate(self)

                return self.to_trans
            end

            # Initialize our new scope.  Defaults to having no parent and to
            # being declarative.
            def initialize(parent = nil, declarative = true)
                @parent = parent
                @nodescope = false

                if @parent.nil?
                    @level = 1

                    @@declarative = declarative

                    # A table for storing nodes.
                    @nodetable = Hash.new(nil)

                    # Eventually, if we support sites, this will allow definitions
                    # of nodes with the same name in different sites.  For now
                    # the top-level scope is always the only site scope.
                    @sitescope = true
                else
                    @parent.child = self
                    @level = @parent.level + 1
                    @interp = @parent.interp
                end

                # Our child scopes
                @children = []

                # The symbol table for this scope
                @symtable = Hash.new(nil)

                # The type table for this scope
                @typetable = Hash.new(nil)

                # The table for storing class singletons.  This will only actually
                # be used by top scopes and node scopes.
                @classtable = Hash.new(nil)

                # All of the defaults set for types.  It's a hash of hashes,
                # with the first key being the type, then the second key being
                # the parameter.
                @defaultstable = Hash.new { |dhash,type|
                    dhash[type] = Hash.new(nil)
                }

                # The object table is similar, but it is actually a hash of hashes
                # where the innermost objects are TransObject instances.
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

                # Map the names to the tables.
                @map = {
                    "variable" => @symtable,
                    "type" => @typetable,
                    "node" => @nodetable,
                    "object" => @objectable,
                    "defaults" => @defaultstable
                }
            end

            # This method abstracts recursive searching.  It accepts the type
            # of search being done and then either a literal key to search for or
            # a Proc instance to do the searching.
            def lookup(type,sub)
                table = @map[type]
                if table.nil?
                    error = Puppet::ParseError.new(
                        "Could not retrieve %s table at level %s" %
                            [type,self.level]
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

            # Look up a given class.  This enables us to make sure classes are
            # singletons
            def lookupclass(klass)
                if self.nodescope? or self.topscope?
                    return @classtable[klass]
                else
                    unless @parent
                        raise Puppet::DevError, "Not top scope but not parent defined"
                    end
                    return @parent.lookupclass(klass)
                end
            end

            # Collect all of the defaults set at any higher scopes.
            # This is a different type of lookup because it's additive --
            # it collects all of the defaults, with defaults in closer scopes
            # overriding those in later scopes.
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
                #Puppet.debug "Got defaults for %s: %s" %
                #    [type,values.inspect]
                return values
            end

            # Look up a node by name
            def lookupnode(name)
                Puppet.debug "Looking up type %s" % name
                value = self.lookup("type",name)
                if value == :undefined
                    return nil
                else
                    Puppet.debug "Found type %s" % name
                    return value
                end
            end

            # Look up a defined type.
            def lookuptype(name)
                Puppet.debug "Looking up type %s" % name
                value = self.lookup("type",name)
                if value == :undefined
                    return nil
                else
                    Puppet.debug "Found type %s" % name
                    return value
                end
            end

            # Look up an object by name and type.
            def lookupobject(name,type)
                Puppet.debug "Looking up object %s of type %s in level %s" %
                    [name, type, @level]
                sub = proc { |table|
                    if table.include?(type)
                        if table[type].include?(name)
                            table[type][name]
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

            # Look up a variable.  The simplest value search we do.
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

            # Create a new scope.
            def newscope
                Puppet.debug "Creating new scope, level %s" % [self.level + 1]
                return Puppet::Parser::Scope.new(self)
            end

            # Store the fact that we've evaluated a given class.
            # FIXME Shouldn't setclass actually store the code, not just a boolean?
            def setclass(klass)
                if self.nodescope? or self.topscope?
                    @classtable[klass] = true
                else
                    @parent.setclass(klass)
                end
            end

            # Set defaults for a type.  The typename should already be downcased,
            # so that the syntax is isolated.
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

            # Define our type.
            def settype(name,ltype)
                @typetable[name] = ltype
            end

            # Return an interpolated string.
            # FIXME We do not yet support a non-interpolated string.
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

            # This is kind of quirky, because it doesn't differentiate between
            # creating a new object and adding params to an existing object.
            # It doesn't solve the real problem, though: cases like file recursion,
            # where one statement explicitly modifies an object, and another
            # statement modifies it because of recursion.
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

            # Set a variable in the current scope.  This will override settings
            # in scopes above, but will not allow variables in the current scope
            # to be reassigned if we're declarative (which is the default).
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

            # Convert our scope to a list of Transportable objects.
            def to_trans
                #Puppet.debug "Translating scope %s at level %s" %
                #    [self.object_id,self.level]

                results = []
                
                # Iterate across our child scopes and call to_trans on them
                @children.each { |child|
                    if child.is_a?(Scope)
                        cresult = child.to_trans
                        #Puppet.debug "Got %s from scope %s" %
                        #    [cresult.class,child.object_id]

                        # Scopes normally result in a TransBucket, but they could
                        # also result in a normal array; if that happens, get rid
                        # of the array.
                        unless cresult.is_a?(TransBucket)
                            cresult.each { |result|
                                results.push(result)
                            }
                        else
                            # Otherwise, just add it to our list of results.
                            results.push(cresult)
                        end

                        # Nodescopes are one-time; once they've been evaluated
                        # I need to destroy them.  Nodeclean makes sure this is
                        # done correctly, but this should catch most of them.
                        if child.nodescope?
                            @children.delete(child)
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

                # Get rid of any nil objects.
                results = results.reject { |child|
                    child.nil?
                }

                # If we have a name and type, then make a TransBucket, which
                # becomes a component.
                # Else, just stack all of the objects into the current bucket.
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
                    #Puppet.debug(
                    #    "TransBucket with name %s and type %s in scope %s" %
                    #    [@name,@type,self.object_id]
                    #)

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
                    Puppet.debug "nameless scope; just returning a list"
                    return results
                end
            end
        end
    end
end

# $Id$
