# The scope class, which handles storing and retrieving variables and types and
# such.

require 'puppet/parser/parser'
require 'puppet/transportable'

module Puppet::Parser
    class Scope
        class ScopeObj < Hash
            attr_accessor :file, :line, :type, :name
        end

        # A simple wrapper for templates, so they don't have full access to
        # the scope objects.
        class TemplateWrapper
            attr_accessor :scope, :file
            include Puppet::Util
            Puppet::Util.logmethods(self)

            def initialize(scope, file)
                @scope = scope
                if file =~ /^#{File::SEPARATOR}/
                    @file = file
                else
                    @file = File.join(Puppet[:templatedir], file)
                end

                unless FileTest.exists?(@file)
                    raise Puppet::ParseError,
                        "Could not find template %s" % file
                end

                # We'll only ever not have an interpreter in testing, but, eh.
                if @scope.interp
                    @scope.interp.newfile(@file)
                end
            end

            def method_missing(name, *args)
                if value = @scope.lookupvar(name.to_s) and value != :undefined and value != ""
                    return value
                else
                    # Just throw an error immediately, instead of searching for
                    # other missingmethod things or whatever.
                    raise Puppet::ParseError,
                        "Could not find value for '%s'" % name
                end
            end

            def result
                result = nil
                benchmark(:debug, "Interpolated template #{@file}") do
                    template = ERB.new(File.read(@file))
                    result = template.result(binding)
                end

                result
            end

            def to_s
                "template[%s]" % @file
            end
        end

        # This doesn't actually work right now.
        Puppet.config.setdefaults(:puppet,
            :lexical => [false, "Whether to use lexical scoping (vs. dynamic)."],
            :templatedir => ["$vardir/templates",
                "Where Puppet looks for template files."
            ]
        )

        Puppet::Util.logmethods(self)

        include Enumerable
        attr_accessor :parent, :level, :interp
        attr_accessor :name, :type, :topscope, :base, :keyword

        attr_accessor :top, :context, :translated, :collectable

        # This is probably not all that good of an idea, but...
        # This way a parent can share its tables with all of its children.
        attr_writer :nodetable, :classtable, :definedtable, :exportable

        # Whether we behave declaratively.  Note that it's a class variable,
        # so all scopes behave the same.
        @@declarative = true

        # Retrieve and set the declarative setting.
        def self.declarative
            return @@declarative
        end

        def self.declarative=(val)
            @@declarative = val
        end

        # Is the value true?  This allows us to control the definition of truth
        # in one place.
        def self.true?(value)
            if value == false or value == ""
                return false
            else
                return true
            end
        end

        # Add all of the defaults for a given object to that object.
        def adddefaults(obj)
            defaults = lookupdefaults(obj.type)

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
                    exobj = @definedtable[type][name]

                    # Either it's a defined type, which are never
                    # isomorphic, or it's a non-isomorphic type.
                    msg = "Duplicate definition: %s[%s] is already defined" %
                        [type, name]

                    if exobj.file and exobj.line
                        msg << " in file %s at line %s" %
                            [exobj.file, exobj.line]
                    end

                    if hash[:line] or hash[:file]
                        msg << "; cannot redefine"
                    end

                    error = Puppet::ParseError.new(msg)
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

            if defined? @exportable
                scope.exportable = @exportable
            else
                raise Puppet::DevError, "No exportable has been defined"
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

        # Are we the top scope?
        def topscope?
            @level == 1
        end

        # Return a list of all of the defined classes.
        def classlist
            unless defined? @classtable
                raise Puppet::DevError, "Scope did not receive class table"
            end
            return @classtable.collect { |id, klass|
                # The class table can contain scopes or strings as its values
                # so support them accordingly.
                if klass.is_a? Scope
                    klass.type
                else
                    klass
                end
            }
        end

        # Yield each child scope in turn
        def each
            @children.each { |child|
                yield child
            }
        end

        # Evaluate a list of classes.
        def evalclasses(classes)
            return unless classes
            classes.each do |klass|
                if code = lookuptype(klass)
                    # Just reuse the 'include' function, since that's the equivalent
                    # of what we're doing here.
                    function_include(klass)
                end
            end
        end

        # Evaluate a specific node's code.  This method will normally be called
        # on the top-level scope, but it actually evaluates the node at the
        # appropriate scope.
        def evalnode(hash)
            objects = hash[:ast]
            names = hash[:names]  or
                raise Puppet::DevError, "Node names must be provided to evalnode"
            facts = hash[:facts]
            classes = hash[:classes]
            parent = hash[:parent]

            # Always add "default" to our name list, so we're always searching
            # for a default node.
            names << "default"

            scope = code = nil
            # Find a node that matches one of our names
            names.each { |node|
                if nodehash = @nodetable[node]
                    code = nodehash[:node]
                    scope = nodehash[:scope]

                    if node == "default"
                        Puppet.info "Using default node"
                    end
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
            # scope so that we can get any classes set within it
            nodescope = code.safeevaluate(:scope => scope, :facts => facts)

            scope.evalclasses(classes)
        end

        # The top-level evaluate, used to evaluate a whole AST tree.  This is
        # a strange method, in that it turns around and calls evaluate() on its
        # :ast argument.
        def evaluate(hash)
            objects = hash[:ast]
            facts = hash[:facts] || {}

            @@done = []

            unless objects
                raise Puppet::DevError, "Evaluation requires an AST tree"
            end

            # Set all of our facts in the top-level scope.
            facts.each { |var, value|
                self.setvar(var, value)
            }

            # Evaluate all of our configuration.  This does not evaluate any
            # node definitions.
            result = objects.safeevaluate(:scope => self)

            # If they've provided a name or a parent, we assume they're looking
            # for nodes.
            if hash[:searched]
                # Specifying a parent node takes precedence, because it is assumed
                # that this node was found in a remote repository like ldap.
                gennode(hash)
            elsif hash.include? :names # else, look for it in the config
                evalnode(hash)
            else
                # Else we're not using nodes at all, so just evaluate any passed-in
                # classes.
                classes = hash[:classes] || []
                evalclasses(classes)

                # These classes would be passed in manually, via something like
                # a cfengine module
            end

            bucket = self.to_trans

            # Add our class list
            unless self.classlist.empty?
                bucket.classes = self.classlist
            end

            # Now clean up after ourselves
            [@@done].each do |table|
                table.clear
            end

            return bucket
        end

        # Return the hash of objects that we specifically exported.  We return
        # a hash to make it easy for the caller to deduplicate based on name.
        def exported(type)
            if @exportable.include?(type)
                return @exportable[type].dup
            else
                return {}
            end
        end

        # Store our object in the central export table.
        def exportobject(obj)
            if @exportable.include?(obj.type) and
                @exportable[obj.type].include?(obj.name)
                    raise Puppet::ParseError, "Object %s[%s] is already exported" %
                        [obj.type, obj.name]
            end

            debug "Exporting %s[%s]" % [obj.type, obj.name]

            @exportable[obj.type][obj.name] = obj

            return obj
        end

        # Pull in all of the appropriate classes and evaluate them.  It'd
        # be nice if this didn't know quite so much about how AST::Node
        # operated internally.  This is used when a list of classes is passed in,
        # instead of a node definition, such as from the cfengine module.
        def gennode(hash)
            names = hash[:names] or
                raise Puppet::DevError, "Node names must be provided to gennode"
            facts = hash[:facts]
            classes = hash[:classes]
            parent = hash[:parentnode]
            name = names.shift
            arghash = {
                :type => name,
                :code => AST::ASTArray.new(:pin => "[]")
            }

            #Puppet.notice "hash is %s" %
            #    hash.inspect
            #Puppet.notice "Classes are %s, parent is %s" %
            #    [classes.inspect, parent.inspect]

            if parent
                arghash[:parentclass] = parent
            end

            # Create the node
            node = AST::Node.new(arghash)
            node.keyword = "node"

            # Now evaluate it, which evaluates the parent and nothing else
            # but does return the nodescope.
            scope = node.safeevaluate(:scope => self)

            # Finally evaluate our list of classes in this new scope.
            scope.evalclasses(classes)
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

            @tags = []

            if @parent.nil?
                unless hash.include?(:declarative)
                    hash[:declarative] = true
                end
                self.istop(hash[:declarative])
                @inside = nil
            else
                # This is here, rather than in newchild(), so that all
                # of the later variable initialization works.
                @parent.child = self

                @level = @parent.level + 1
                @interp = @parent.interp
                @topscope = @parent.topscope
                @context = @parent.context
                @inside = @parent.inside
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

        # Associate the object directly with the scope, so that contained objects
        # can look up what container they're running within.
        def inside(arg = nil)
            return @inside unless arg

            old = @inside
            @inside = arg
            yield
        ensure
            #Puppet.warning "exiting %s" % @inside.name
            @inside = old
        end

        # Mark that we're the top scope, and set some hard-coded info.
        def istop(declarative = true)
            # the level is mostly used for debugging
            @level = 1

            # The table for storing class singletons.  This will only actually
            # be used by top scopes and node scopes.
            @classtable = Hash.new(nil)

            self.class.declarative = declarative

            # The table for all defined objects.
            @definedtable = Hash.new { |types, type|
                types[type] = {}
            }

            # A table for storing nodes.
            @nodetable = Hash.new(nil)

            # The list of objects that will available for export.
            @exportable = Hash.new { |types, type|
                types[type] = {}
            }

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

        # Look up a given class.  This enables us to make sure classes are
        # singletons
        def lookupclass(klassid)
            unless defined? @classtable
                raise Puppet::DevError, "Scope did not receive class table"
            end
            return @classtable[klassid]
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

        # Look up all of the exported objects of a given type.  Just like
        # lookupobject, this only searches up through parent classes, not
        # the whole scope tree.
        def lookupexported(type)
            found = []
            sub = proc { |table|
                # We always return nil so that it will search all the way
                # up the scope tree.
                if table.has_key?(type)
                    table[type].each do |name, obj|
                        found << obj
                    end
                    nil
                else
                    info table.keys.inspect
                    nil
                end
            }

            value = lookup("object",sub, false)

            return found
        end

        # Look up a node by name
        def lookupnode(name)
            #Puppet.debug "Looking up type %s" % name
            value = lookup("type",name)
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
            value = lookup("type",name)
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
            value = lookup("object",sub, true)
            if value == :undefined
                return nil
            else
                return value
            end
        end

        # Look up a variable.  The simplest value search we do.
        def lookupvar(name)
            value = lookup("variable", name)
            if value == :undefined
                return ""
            else
                return value
            end
        end

        def newcollection(coll)
            @children << coll
        end

        # Add a new object to our object table.
        def newobject(hash)
            if @objectable[hash[:type]].include?(hash[:name])
                raise Puppet::DevError, "Object %s[%s] is already defined" %
                    [hash[:type], hash[:name]]
            end

            self.chkobjectclosure(hash)

            obj = nil

            obj = Puppet::TransObject.new(hash[:name], hash[:type])

            @children << obj

            @objectable[hash[:type]][hash[:name]] = obj

            @definedtable[hash[:type]][hash[:name]] = obj

            return obj
        end

        # Create a new scope.
        def newscope(hash = {})
            hash[:parent] = self
            #debug "Creating new scope, level %s" % [self.level + 1]
            return Puppet::Parser::Scope.new(hash)
        end

        # Retrieve a specific node.  This is used in ast.rb to find a
        # parent node and in findnode to retrieve and evaluate a node.
        def node(name)
            @nodetable[name]
        end

        # Store the fact that we've evaluated a given class.  We use a hash
        # that gets inherited from the top scope down, rather than a global
        # hash.  We store the object ID, not class name, so that we
        # can support multiple unrelated classes with the same name.
        def setclass(id, name)
            unless name =~ /^[a-z][\w-]*$/
                raise Puppet::ParseError, "Invalid class name '%s'" % name
            end

            @classtable[id] = name
        end

        # Store the scope for each class, so that other subclasses can look
        # them up.
        def setscope(id, scope)
            @classtable[id] = scope
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
                code.scope = self
                @nodetable[name] = {
                    :scope => self,
                    :node => code
                }
            end
        end

        # Define our type.
        def settype(name,ltype)
            unless name
                raise Puppet::DevError, "Got told to set type with a nil type"
            end
            unless ltype
                raise Puppet::DevError, "Got told to set type with a nil object"
            end
            # Don't let them redefine the class in this scope.
            if @typetable.include?(name)
                raise Puppet::ParseError,
                    "%s is already defined" % name
            else
                ltype.scope = self
                @typetable[name] = ltype
            end
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

            collectable = hash[:collectable] || self.collectable

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

            # First look for it in a parent scope
            obj = lookupobject(:name => name, :type => type)

            if obj
                unless collectable == obj.collectable
                    msg = nil
                    if collectable
                        msg = "Exported %s[%s] cannot override local objects"
                            [type, name]
                    else
                        msg = "Local %s[%s] cannot override exported objects"
                            [type, name]
                    end

                    error = Puppet::ParseError.new(msg)
                    error.line = line
                    error.file = file
                    raise error
                end
            end

            unless obj and obj != :undefined
                unless obj = @objectable[type][name]
                    obj = self.newobject(
                        :type => type,
                        :name => name,
                        :line => line,
                        :file => file
                    )

                    obj.collectable = collectable

                    # only set these if we've created the object,
                    # which is the most common case
                    # FIXME we eventually need to store the file
                    # and line with each param, not the object
                    # itself.
                    obj.file = file
                    obj.line = line
                end
            end

            # Now add our parameters.  This has the function of overriding
            # existing values, which might have been defined in a higher
            # scope.
            params.each { |var,value|
                # Add it to our found object
                obj[var] = value
            }

            # This is only used for override verification -- the local object
            # table does not have transobjects or whatever in it, it just has
            # simple hashes.  This is necessary because setobject can modify
            # our object table or a parent class's object table, and we
            # still need to make sure param settings cannot be duplicated
            # within our scope.
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

        # Return an interpolated string.
        def strinterp(string)
            newstring = string.gsub(/\\\$|\$\{(\w+)\}|\$(\w+)/) do |value|
                # If it matches the backslash, then just retun the dollar sign.
                if value == '\\$'
                    '$'
                else # look the variable up
                    var = $1 || $2
                    lookupvar($1 || $2)
                end
            end

            return newstring.gsub(/\\t/, "\t").gsub(/\\n/, "\n").gsub(/\\s/, "\s")
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
                #info "Looking for tags in %s" % @parent.type
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

        # Convert our scope to a TransBucket.  Everything in our @localobjecttable
        # gets converted to either an evaluated definition, or a TransObject
        def to_trans
            results = []

            # Set this on entry, just in case someone tries to get all weird
            @translated = true

            @children.dup.each do |child|
                if @@done.include?(child)
                    raise Puppet::DevError, "Already translated %s" %
                        child.object_id
                else
                    @@done << child
                end
                #warning "Working on %s of type %s with id %s" %
                #    [child.type, child.class, child.object_id]

                # If it's a scope, then it can only be a subclass's scope, so
                # convert it to a transbucket and store it in our results list
                result = nil
                case child
                when Scope
                    result = child.to_trans
                when Puppet::TransObject
                    # These objects can map to defined types or builtin types.
                    # Builtin types should be passed out as they are, but defined
                    # types need to be evaluated.  We have to wait until this
                    # point so that subclass overrides can happen.

                    # Wait until the last minute to set tags, although this
                    # probably should not matter
                    child.tags = self.tags

                    # Add any defaults.
                    self.adddefaults(child)

                    # Then make sure this child's tags are stored in the
                    # central table.  This should maybe be in the evaluate
                    # methods, but, eh.
                    @topscope.addtags(child)

                    # Now that all that is done, check to see what kind of object
                    # it is.
                    if objecttype = lookuptype(child.type)
                        # It's a defined type, so evaluate it.  Retain whether
                        # the object is collectable.  If the object is collectable,
                        # then it will store all of its contents into the
                        # @exportable table, rather than returning them.
                        result = objecttype.safeevaluate(
                            :name => child.name,
                            :type => child.type,
                            :arguments => child.to_hash,
                            :scope => self,
                            :collectable => child.collectable
                        )
                    else
                        # If it's collectable, then store it.  It will be
                        # stripped out in the interpreter using the collectstrip
                        # method.  If we don't do this, then these objects
                        # don't get stored in the DB.
                        if child.collectable
                            exportobject(child)
                        end
                        result = child
                    end
                # This is pretty hackish, but the collection has to actually
                # be performed after all of the classes and definitions are
                # evaluated, otherwise we won't catch objects that are exported
                # in them.  I think this will still be pretty limited in some
                # cases, especially those where you are both exporting and
                # collecting, but it's the best I can do for now.
                when Puppet::Parser::AST::Collection
                    child.perform(self).each do |obj|
                        results << obj
                    end
                else
                    raise Puppet::DevError,
                        "Puppet::Parse::Scope cannot handle objects of type %s" %
                            child.class
                end

                # Skip nil objects or empty transbuckets
                if result
                    unless result.is_a? Puppet::TransBucket and result.empty?
                        results << result
                    end
                end
            end

            # Get rid of any nil objects.
            results.reject! { |child|
                child.nil?
            }

            # If we have a name and type, then make a TransBucket, which
            # becomes a component.
            # Else, just stack all of the objects into the current bucket.
            if @type
                bucket = Puppet::TransBucket.new

                if defined? @name and @name
                    bucket.name = @name
                end
                # it'd be nice not to have to do this...
                results.each { |result|
                    #Puppet.warning "Result type is %s" % result.class
                    bucket.push(result)
                }
                bucket.type = @type

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
                Puppet.debug "typeless scope; just returning a list"
                return results
            end
        end

        # Undefine a variable; only used for testing.
        def unsetvar(var)
            if @symtable.include?(var)
                @symtable.delete(var)
            end
        end

        protected

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
                # Context is used for retricting overrides.
                if usecontext and self.context != @parent.context
                    return :undefined
                else
                    return @parent.lookup(type,sub, usecontext)
                end
            else
                return :undefined
            end
        end
    end
end

# $Id$
