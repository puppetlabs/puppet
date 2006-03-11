# The scope class, which handles storing and retrieving variables and types and
# such.

require 'puppet/transportable'

module Puppet
    module Parser
        class Scope
            class ScopeObj < Hash
                attr_accessor :file, :line, :type, :name
            end

            Puppet::Util.logmethods(self)

            include Enumerable
            attr_accessor :parent, :level, :interp
            attr_accessor :name, :type, :topscope, :base, :keyword

            attr_accessor :top, :context

            # This is probably not all that good of an idea, but...
            # This way a parent can share its tables with all of its children.
            attr_writer :nodetable, :classtable, :definedtable

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

            # Add all of the defaults for a given object to that object.
            def adddefaults(obj)
                defaults = self.lookupdefaults(obj.type)

                defaults.each do |var, value|
                    unless obj[var]
                        self.debug "Adding default %s for %s" %
                            [var, obj.type]

                        obj[var] = value
                    end
                end
            end

            # Add a single object's tags to the global list of tags for
            # that object.
            def addtags(obj)
                unless defined? @tagtable
                    raise Puppet::DevError, "Told to add tags, but no tag table"
                end
                list = @tagtable[obj.type][obj.name]

                obj.tags.each { |tag|
                    unless list.include?(tag)
                        if tag.nil? or tag == ""
                            Puppet.debug "Got tag %s from %s(%s)" %
                                [tag.inspect, obj.type, obj.name]
                        else
                            list << tag
                        end
                    end
                }
            end

            # Is the type a builtin type?
            def builtintype?(type)
                if typeklass = Puppet::Type.type(type)
                    return typeklass
                else
                    return false
                end
            end

            # Verify that the given object isn't defined elsewhere.
            def chkobjectclosure(hash)
                type = hash[:type]
                name = hash[:name]
                unless name
                    return true
                end
                if @definedtable[type].include?(name)
                    typeklass = Puppet::Type.type(type)
                    if typeklass and ! typeklass.isomorphic?
                        Puppet.info "Allowing duplicate %s" % type
                    else
                        # Either it's a defined type, which are never
                        # isomorphic, or it's a non-isomorphic type.
                        msg = "Duplicate definition: %s[%s] is already defined" %
                            [type, name]
                        error = Puppet::ParseError.new(msg)
                        if hash[:line]
                            error.line = hash[:line]
                        end
                        if hash[:file]
                            error.file = hash[:file]
                        end
                        raise error
                    end
                end

                return true
            end

            def declarative=(val)
                self.class.declarative = val
            end

            def declarative
                self.class.declarative
            end

            # Log the existing tags.  At some point this should be in a better
            # place, but eh.
            def logtags
                @tagtable.sort { |a, b|
                    a[0] <=> b[0]
                }.each { |type, names|
                    names.sort { |a, b|
                        a[0] <=> b[0]
                    }.each { |name, tags|
                        Puppet.info "%s(%s): '%s'" % [type, name, tags.join("' '")]
                    }
                }
            end

            # Create a new child scope.
            def child=(scope)
                @children.push(scope)

                if defined? @nodetable
                    scope.nodetable = @nodetable
                else
                    raise Puppet::DevError, "No nodetable has been defined"
                end

                if defined? @classtable
                    scope.classtable = @classtable
                else
                    raise Puppet::DevError, "No classtable has been defined"
                end

                if defined? @definedtable
                    scope.definedtable = @definedtable
                else
                    raise Puppet::DevError, "No definedtable has been defined"
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

            # Mark that we are a nodescope.
            def isnodescope
                @nodescope = true

                # Also, create the extra tables associated with being a node
                # scope.
                # The table for storing class singletons.
                @classtable = Hash.new(nil)

                # Also, create the object checking map
                @definedtable = Hash.new { |types, type|
                    types[type] = {}
                }
            end

            # Are we the top scope?
            def topscope?
                @level == 1
            end

            # Return a list of all of the defined classes.
            def classlist
                unless defined? @classtable
                    raise Puppet::DevError, "Scope did not receive class table"
                end
                return @classtable.keys
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
            #def evalnode(names, facts, classes = nil, parent = nil)
            def evalnode(hash)
                names = hash[:name] 
                facts = hash[:facts]
                classes = hash[:classes]
                parent = hash[:parent]
                # First make sure there aren't any other node scopes lying around
                self.nodeclean

                # If they've passed classes in, then just generate from there.
                if classes
                    return self.gennode(
                        :names => names,
                        :facts => facts,
                        :classes => classes,
                        :parent => parent
                    )
                end

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

                # We need to do a little skullduggery here.  We want a
                # temporary scope, because we don't want this scope to
                # show up permanently in the scope tree -- otherwise we could
                # not evaluate the node multiple times.  We could conceivably
                # cache the results, but it's not worth it at this stage.

                # Note that we evaluate the node code with its containing
                # scope, not with the top scope.  We also retrieve the created
                # nodescope so that we can get any classes set within it
                nodescope = code.safeevaluate(:scope => scope, :facts => facts)

                # We don't need to worry about removing the Node code because
                # it will be removed during translation.

                # convert the whole thing
                objects = self.to_trans

                # Add any evaluated classes to our top-level object
                unless nodescope.classlist.empty?
                    objects.classes = nodescope.classlist
                end

                if objects.is_a?(Puppet::TransBucket)
                    objects.top = true
                end
                # I should do something to add the node as an object with tags
                # but that will possibly end up with far too many tags.
                #self.logtags
                return objects
            end

            # Pull in all of the appropriate classes and evaluate them.  It'd
            # be nice if this didn't know quite so much about how AST::Node
            # operated internally.
            #def gennode(names, facts, classes, parent)
            def gennode(hash)
                names = hash[:names]
                facts = hash[:facts]
                classes = hash[:classes]
                parent = hash[:parent]
                name = names.shift
                arghash = {
                    :type => name,
                    :code => AST::ASTArray.new(:pin => "[]")
                }

                if parent
                    arghash[:parentclass] = parent
                end

                # Create the node
                node = AST::Node.new(arghash)
                node.keyword = "node"

                # Now evaluate it, which evaluates the parent but doesn't really
                # do anything else but does return the nodescope
                scope = node.safeevaluate(:scope => self)

                # And now evaluate each set klass within the nodescope.
                classes.each { |klass|
                    if code = scope.lookuptype(klass)
                        #code.safeevaluate(scope, {}, klass, klass)
                        code.safeevaluate(
                            :scope => scope,
                            :facts => {},
                            :type => klass
                        )
                    end
                }

                return scope.to_trans
            end

            # Retrieve a specific node.  This is used in ast.rb to find a
            # parent node and in findnode to retrieve and evaluate a node.
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

            # Evaluate normally, with no node definitions.  This is a bit of a
            # silly method, in that it just calls evaluate on the passed-in
            # objects, and then calls to_trans on itself.  It just conceals
            # a paltry amount of info from whomever's using the scope object.
            def evaluate(hash)
                objects = hash[:ast]
                facts = hash[:facts] || {}
                classes = hash[:classes] || []
                facts.each { |var, value|
                    self.setvar(var, value)
                }

                objects.safeevaluate(:scope => self)

                # These classes would be passed in manually, via something like
                # a cfengine module
                classes.each { |klass|
                    if code = self.lookuptype(klass)
                        code.safeevaluate(
                            :scope => self,
                            :facts => {},
                            :type => klass
                        )
                    end
                }

                objects = self.to_trans
                objects.top = true

                # Add our class list
                unless self.classlist.empty?
                    objects.classes = self.classlist
                end

                return objects
            end

            # Take all of our objects and evaluate them.
            def finish
                self.info "finishing"
                @objectlist.each { |object|
                    if object.is_a? ScopeObj
                        self.info "finishing %s" % object.name
                        if obj = finishobject(object)
                            @children << obj
                        end
                    end
                }

                @finished = true

                self.info "finished"
            end

            # If the object is defined in an upper scope, then add our
            # params to that upper scope; else, create a transobject
            # or evaluate the definition.
            def finishobject(object)
                type = object.type
                name = object.name

                # It should be a defined type.
                definedtype = self.lookuptype(type)

                unless definedtype
                    error = Puppet::ParseError.new("No such type %s" % type)
                    error.line = object.line
                    error.file = object.file
                    raise error
                end

                return definedtype.safeevaluate(
                    :scope => self,
                    :arguments => object,
                    :type => type,
                    :name => name
                )
            end

            def finished?
                @finished
            end

            # Initialize our new scope.  Defaults to having no parent and to
            # being declarative.
            def initialize(hash = {})
                @parent = nil
                @type = nil
                @name = nil
                @finished = false
                hash.each { |name, val|
                    method = name.to_s + "="
                    if self.respond_to? method
                        self.send(method, val)
                    else
                        raise Puppet::DevError, "Invalid scope argument %s" % name
                    end
                }
                #@parent = hash[:parent]
                @nodescope = false

                @tags = []

                if @parent.nil?
                    unless hash.include?(:declarative)
                        hash[:declarative] = true
                    end
                    self.istop(hash[:declarative])
                else
                    @parent.child = self
                    @level = @parent.level + 1
                    @interp = @parent.interp
                    @topscope = @parent.topscope
                    @context = @parent.context
                end

                # Our child scopes and objects
                @children = []

                # The symbol table for this scope
                @symtable = Hash.new(nil)

                # The type table for this scope
                @typetable = Hash.new(nil)

                # All of the defaults set for types.  It's a hash of hashes,
                # with the first key being the type, then the second key being
                # the parameter.
                @defaultstable = Hash.new { |dhash,type|
                    dhash[type] = Hash.new(nil)
                }

                # The object table is similar, but it is actually a hash of hashes
                # where the innermost objects are TransObject instances.
                @objectable = Hash.new { |typehash,typekey|
                    # See #newobject for how to create the actual objects
                    typehash[typekey] = Hash.new(nil)
                }

                # The list of simpler hash objects.
                @objectlist = []

                # This is just for collecting statements locally, so we can
                # verify that there is no overlap within this specific scope
                @localobjectable = Hash.new { |typehash,typekey|
                    typehash[typekey] = Hash.new(nil)
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

            # Mark that we're the top scope, and set some hard-coded info.
            def istop(declarative = true)
                # the level is mostly used for debugging
                @level = 1

                # The table for storing class singletons.  This will only actually
                # be used by top scopes and node scopes.
                @classtable = Hash.new(nil)

                self.class.declarative = declarative

                # The table for all defined objects.  This will only be
                # used in the top scope if we don't have any nodescopes.
                @definedtable = Hash.new { |types, type|
                    types[type] = {}
                }

                # A table for storing nodes.
                @nodetable = Hash.new(nil)

                # Eventually, if we support sites, this will allow definitions
                # of nodes with the same name in different sites.  For now
                # the top-level scope is always the only site scope.
                @sitescope = true

                # And create a tag table, so we can collect all of the tags
                # associated with any objects created in this scope tree
                @tagtable = Hash.new { |types, type|
                    types[type] = Hash.new { |names, name|
                        names[name] = []
                    }
                }

                @context = nil
                @topscope = self
                @type = "puppet"
                @name = "top"
            end

            # This method abstracts recursive searching.  It accepts the type
            # of search being done and then either a literal key to search for or
            # a Proc instance to do the searching.
            def lookup(type,sub, usecontext = false)
                table = @map[type]
                if table.nil?
                    error = Puppet::ParseError.new(
                        "Could not retrieve %s table at level %s" %
                            [type,self.level]
                    )
                    raise error
                end

                if sub.is_a?(Proc) and obj = sub.call(table)
                    return obj
                elsif table.include?(sub)
                    return table[sub]
                elsif ! @parent.nil?
                    #self.notice "Context is %s, parent %s is %s" %
                    #    [self.context, @parent.type, @parent.context]
                    if usecontext and self.context != @parent.context
                        return :undefined
                    else
                        return @parent.lookup(type,sub, usecontext)
                    end
                else
                    return :undefined
                end
            end

            # Look up a given class.  This enables us to make sure classes are
            # singletons
            def lookupclass(klass)
                unless defined? @classtable
                    raise Puppet::DevError, "Scope did not receive class table"
                end
                return @classtable[klass]
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
                #Puppet.debug "Looking up type %s" % name
                value = self.lookup("type",name)
                if value == :undefined
                    return nil
                else
                    #Puppet.debug "Found node %s" % name
                    return value
                end
            end

            # Look up a defined type.
            def lookuptype(name)
                #Puppet.debug "Looking up type %s" % name
                value = self.lookup("type",name)
                if value == :undefined
                    return nil
                else
                    #Puppet.debug "Found type %s" % name
                    return value
                end
            end

            # Look up an object by name and type.  This should only look up objects
            # within a class structure, not within the entire scope structure.
            def lookupobject(hash)
                type = hash[:type]
                name = hash[:name]
                #Puppet.debug "Looking up object %s of type %s in level %s" %
                #    [name, type, @level]
                sub = proc { |table|
                    if table.include?(type)
                        if table[type].include?(name)
                            table[type][name]
                        end
                    else
                        nil
                    end
                }
                value = self.lookup("object",sub, true)
                if value == :undefined
                    return nil
                else
                    return value
                end
            end

            # Look up a variable.  The simplest value search we do.
            def lookupvar(name)
                #Puppet.debug "Looking up variable %s" % name
                value = self.lookup("variable", name)
                if value == :undefined
                    return ""
                    #error = Puppet::ParseError.new(
                    #    "Undefined variable '%s'" % name
                    #)
                    #raise error
                else
                    return value
                end
            end

            # Add a new object to our object table.
            def newobject(hash)
                if @objectable[hash[:type]].include?(hash[:name])
                    raise Puppet::DevError, "Object %s[%s] is already defined" %
                        [hash[:type], hash[:name]]
                end

                self.chkobjectclosure(hash)

                obj = nil

                # If it's a builtin type, then use a transobject, else use
                # a ScopeObj, which will get replaced later.
                if self.builtintype?(hash[:type])
                    obj = TransObject.new(hash[:name], hash[:type])

                    @children << obj
                else
                    obj = ScopeObj.new(nil)
                    obj.name = hash[:name]
                    obj.type = hash[:type]
                end

                @objectable[hash[:type]][hash[:name]] = obj

                @definedtable[hash[:type]][hash[:name]] = obj

                # Keep them in order, just for kicks
                @objectlist << obj

                return obj
            end

            # Create a new scope.
            def newscope(hash = {})
                hash[:parent] = self
                #Puppet.debug "Creating new scope, level %s" % [self.level + 1]
                return Puppet::Parser::Scope.new(hash)
            end

            # Store the fact that we've evaluated a given class.  We use a hash
            # that gets inherited from the nodescope down, rather than a global
            # hash.  We store the object ID, not class name, so that we
            # can support multiple unrelated classes with the same name.
            def setclass(id)
                if self.nodescope? or self.topscope?
                    @classtable[id] = true
                else
                    @parent.setclass(id)
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
                    #Puppet.debug "Default for %s is %s => %s" %
                    #    [type,ary[0].inspect,ary[1].inspect]
                    if @@declarative
                        if table.include?(ary[0])
                            error = Puppet::ParseError.new(
                                "Default already defined for %s { %s }" %
                                    [type,ary[0]]
                            )
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
                # Don't let them redefine the class in this scope.
                if @typetable.include?(name)
                    raise Puppet::ParseError,
                        "%s is already defined" % name
                else
                    @typetable[name] = ltype
                end
            end

            # Return an interpolated string.
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
                return newstring.gsub(/\\t/, "\t").gsub(/\\n/, "\n").gsub(/\\s/, "\s")
            end

            # This method will fail if the named object is already defined anywhere
            # in the scope tree, which is what provides some minimal closure-like
            # behaviour.
            def setobject(hash)
                # FIXME This objectlookup stuff should be looking up using both
                # the name and the namevar.

                # First see if we can look the object up using normal scope
                # rules, i.e., one of our parent classes has defined the
                # object or something

                name = hash[:name]
                type = hash[:type]
                params = hash[:arguments]
                file = hash[:file]
                line = hash[:line]

                # Verify that we're not overriding any already-set parameters.
                if localobj = @localobjectable[type][name]
                    params.each { |var, value|
                        if localobj.include?(var)
                            msg = "Cannot reassign attribute %s on %s[%s]" %
                                [var, type, name]

                            error = Puppet::ParseError.new(msg)
                            error.line = line
                            error.file = file
                            raise error
                        end
                    }
                end

                if objecttype = self.lookuptype(type)
                    # It's a defined type
                    objecttype.safeevaluate(
                        :name => name,
                        :type => type,
                        :arguments => params,
                        :scope => self
                    )
                else
                    # First look for it in a parent scope
                    obj = self.lookupobject(:name => name, :type => type)

                    unless obj and obj != :undefined
                        unless obj = @objectable[type][name]
                            obj = self.newobject(
                                :type => type,
                                :name => name,
                                :line => line,
                                :file => file
                            )

                            # only set these if we've created the object,
                            # which is the most common case
                            # FIXME we eventually need to store the file
                            # and line with each param, not the object
                            # itself.
                            obj.file = file
                            obj.line = line
                        end

                        # Now add our parameters.  This has the function of
                        # overriding existing values, which might have been
                        # defined in a higher scope.
                    end
                    params.each { |var,value|
                        # Add it to our found object
                        obj[var] = value
                    }
                end

                @localobjectable[type][name] ||= {}

                params.each { |var,value|
                    # And add it to the local table; mmm, hack
                    @localobjectable[type][name][var] = value
                }

                return obj
            end

            # Set a variable in the current scope.  This will override settings
            # in scopes above, but will not allow variables in the current scope
            # to be reassigned if we're declarative (which is the default).
            def setvar(name,value)
                #Puppet.debug "Setting %s to '%s' at level %s" %
                #    [name.inspect,value,self.level]
                if @@declarative and @symtable.include?(name)
                    raise Puppet::ParseError, "Cannot reassign variable %s" % name
                else
                    if @symtable.include?(name)
                        Puppet.warning "Reassigning %s to %s" % [name,value]
                    end
                    @symtable[name] = value
                end
            end

            # Add a tag to our current list.  These tags will be added to all
            # of the objects contained in this scope.
            def tag(*ary)
                ary.each { |tag|
                    if tag.nil? or tag == ""
                        Puppet.debug "got told to tag with %s" % tag.inspect
                        next
                    end
                    unless @tags.include?(tag)
                        #Puppet.info "Tagging scope %s with %s" % [self.object_id, tag]
                        @tags << tag.to_s
                    end
                }
            end

            # Return the tags associated with this scope.  It's basically
            # just our parents' tags, plus our type.
            def tags
                tmp = [] + @tags
                unless ! defined? @type or @type.nil? or @type == ""
                    tmp << @type.to_s
                end
                if @parent
                    @parent.tags.each { |tag|
                        if tag.nil? or tag == ""
                            Puppet.debug "parent returned tag %s" % tag.inspect
                            next
                        end
                        unless tmp.include?(tag)
                            tmp << tag
                        end
                    }
                end
                return tmp
            end

            # Used mainly for logging
            def to_s
                if @name
                    return "%s[%s]" % [@type, @name]
                else
                    return @type.to_s
                end
            end

            # Convert our scope to a list of Transportable objects.
            def to_trans
                #unless self.finished?
                #    raise Puppet::DevError, "%s not finished" % self.type
                #    self.err "Not finished"
                #    self.finish
                #end
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
                            unless cresult.empty?
                                # Otherwise, just add it to our list of results.
                                results.push(cresult)
                            end
                        end

                        # Nodescopes are one-time; once they've been evaluated
                        # I need to destroy them.  Nodeclean makes sure this is
                        # done correctly, but this should catch most of them.
                        if child.nodescope?
                            @children.delete(child)
                        end
                    elsif child.is_a?(TransObject)
                        if child.empty?
                            next
                        end
                        # Wait until the last minute to set tags, although this
                        # probably should not matter
                        child.tags = self.tags

                        # Add any defaults.
                        self.adddefaults(child)

                        # Then make sure this child's tags are stored in the
                        # central table.  This should maybe be in the evaluate
                        # methods, but, eh.
                        @topscope.addtags(child)
                        results.push(child)
                    else
                        raise Puppet::DevError,
                            "Puppet::Parse::Scope cannot handle objects of type %s" %
                                child.class
                    end
                }

                # Get rid of any nil objects.
                results = results.reject { |child|
                    child.nil?
                }

                # If we have a name and type, then make a TransBucket, which
                # becomes a component.
                # Else, just stack all of the objects into the current bucket.
                if @type
                    bucket = TransBucket.new

                    if defined? @name and @name
                        bucket.name = @name
                    end

                    # it'd be nice not to have to do this...
                    results.each { |result|
                        #Puppet.warning "Result type is %s" % result.class
                        bucket.push(result)
                    }
                    if defined? @type
                        bucket.type = @type
                    else
                        raise Puppet::ParseError,
                            "No type for scope %s" % @name
                    end

                    if defined? @keyword
                        bucket.keyword = @keyword
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
                    #Puppet.debug "nameless scope; just returning a list"
                    return results
                end
            end
        end
    end
end

# $Id$
