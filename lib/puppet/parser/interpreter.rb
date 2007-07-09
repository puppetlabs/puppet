require 'puppet'
require 'timeout'
require 'puppet/rails'
require 'puppet/util/methodhelper'
require 'puppet/parser/parser'
require 'puppet/parser/scope'

# The interpreter's job is to convert from a parsed file to the configuration
# for a given client.  It really doesn't do any work on its own, it just collects
# and calls out to other objects.
class Puppet::Parser::Interpreter
    class NodeDef
        include Puppet::Util::MethodHelper
        attr_accessor :name, :classes, :parameters, :source

        def evaluate(options)
            begin
                parameters.each do |param, value|
                    # Don't try to override facts with these parameters
                    options[:scope].setvar(param, value) unless options[:scope].lookupvar(param, false) != :undefined
                end

                # Also, set the 'nodename', since it might not be obvious how the node was looked up
                options[:scope].setvar("nodename", @name) unless options[:scope].lookupvar(@nodename, false) != :undefined
            rescue => detail
                raise Puppet::ParseError, "Could not set parameters for %s: %s" % [name, detail]
            end

            # Then evaluate the classes.
            begin
                options[:scope].function_include(classes.find_all { |c| options[:scope].findclass(c) })
            rescue => detail
                raise Puppet::ParseError, "Could not evaluate classes for %s: %s" % [name, detail]
            end
        end

        def initialize(args)
            set_options(args)

            raise Puppet::DevError, "NodeDefs require names" unless self.name

            if self.classes.is_a?(String)
                @classes = [@classes]
            else
                @classes ||= []
            end
            @parameters ||= {}
        end

        def safeevaluate(args)
            evaluate(args)
        end
    end

    include Puppet::Util

    attr_accessor :usenodes

    class << self
        attr_writer :ldap
    end
    # just shorten the constant path a bit, using what amounts to an alias
    AST = Puppet::Parser::AST

    include Puppet::Util::Errors

    # Create an ldap connection.  This is a class method so others can call
    # it and use the same variables and such.
    def self.ldap
        unless defined? @ldap and @ldap
            if Puppet[:ldapssl]
                @ldap = LDAP::SSLConn.new(Puppet[:ldapserver], Puppet[:ldapport])
            elsif Puppet[:ldaptls]
                @ldap = LDAP::SSLConn.new(
                    Puppet[:ldapserver], Puppet[:ldapport], true
                )
            else
                @ldap = LDAP::Conn.new(Puppet[:ldapserver], Puppet[:ldapport])
            end
            @ldap.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
            @ldap.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
            @ldap.simple_bind(Puppet[:ldapuser], Puppet[:ldappassword])
        end

        return @ldap
    end

    # Make sure we don't have any remaining collections that specifically
    # look for resources, because we want to consider those to be
    # parse errors.
    def check_resource_collections(scope)
        remaining = []
        scope.collections.each do |coll|
            if r = coll.resources
                if r.is_a?(Array)
                    remaining += r
                else
                    remaining << r
                end
            end
        end
        unless remaining.empty?
            raise Puppet::ParseError, "Failed to find virtual resources %s" %
                remaining.join(', ')
        end
    end

    def clear
        initparsevars
    end

    # Iteratively evaluate all of the objects.  This finds all of the objects
    # that represent definitions and evaluates the definitions appropriately.
    # It also adds defaults and overrides as appropriate.
    def evaliterate(scope)
        count = 0
        loop do
            count += 1
            done = true
            # First perform collections, so we can collect defined types.
            if coll = scope.collections and ! coll.empty?
                exceptwrap do
                    coll.each do |c|
                        # Only keep the loop going if we actually successfully
                        # collected something.
                        if o = c.evaluate
                            done = false
                        end
                    end
                end
            end
            
            # Then evaluate any defined types.
            if ary = scope.unevaluated
                ary.each do |resource|
                    resource.evaluate
                end
                # If we evaluated, then loop through again.
                done = false
            end
            break if done
            
            if count > 1000
                raise Puppet::ParseError, "Got 1000 class levels, which is unsupported"
            end
        end
    end

    # Evaluate a specific node.
    def evalnode(client, scope, facts)
        return unless self.usenodes

        unless client
            raise Puppet::Error,
                "Cannot evaluate nodes with a nil client"
        end
        names = [client]

        # Make sure both the fqdn and the short name of the
        # host can be used in the manifest
        if client =~ /\./
            names << client.sub(/\..+/,'')
        else
            names << "#{client}.#{facts['domain']}"
        end

        if names.empty?
            raise Puppet::Error,
                "Cannot evaluate nodes with a nil client"
        end

        # Look up our node object.
        if nodeclass = nodesearch(*names)
            nodeclass.safeevaluate :scope => scope
        else
            raise Puppet::Error, "Could not find %s with names %s" %
                [client, names.join(", ")]
        end
    end

    # Evaluate all of the code we can find that's related to our client.
    def evaluate(client, facts)

        scope = Puppet::Parser::Scope.new(:interp => self) # no parent scope
        scope.name = "top"
        scope.type = "main"

        scope.host = client || facts["hostname"] || Facter.value(:hostname)

        classes = @classes.dup

        # Okay, first things first.  Set our facts.
        scope.setfacts(facts)

        # Everyone will always evaluate the top-level class, if there is one.
        if klass = findclass("", "")
            # Set the source, so objects can tell where they were defined.
            scope.source = klass
            klass.safeevaluate :scope => scope, :nosubscope => true
        end

        # Next evaluate the node.  We pass the facts so they can be used
        # when building the list of names for which to search.
        evalnode(client, scope, facts)

        # If we were passed any classes, evaluate those.
        if classes
            classes.each do |klass|
                if klassobj = findclass("", klass)
                    klassobj.safeevaluate :scope => scope
                end
            end
        end

        # That was the first pass evaluation.  Now iteratively evaluate
        # until we've gotten rid of all of everything or thrown an error.
        evaliterate(scope)

        # Now make sure we fail if there's anything left to do
        failonleftovers(scope)

        # Now finish everything.  This recursively calls finish on the
        # contained scopes and resources.
        scope.finish

        # Store everything.  We need to do this before translation, because
        # it operates on resources, not transobjects.
        if Puppet[:storeconfigs]
            args = {
                :resources => scope.resources,
                :name => scope.host,
                :facts => facts
            }
            unless scope.classlist.empty?
                args[:classes] = scope.classlist
            end

            storeconfigs(args)
        end

        # Now, finally, convert our scope tree + resources into a tree of
        # buckets and objects.
        objects = scope.translate

        # Add the class list
        unless scope.classlist.empty?
            objects.classes = scope.classlist
        end

        return objects
    end

    # Fail if there any overrides left to perform.
    def failonleftovers(scope)
        overrides = scope.overrides
        unless overrides.empty?
            fail Puppet::ParseError,
                "Could not find object(s) %s" % overrides.collect { |o|
                    o.ref
                }.join(", ")
        end

        # Now check that there aren't any extra resource collections.
        check_resource_collections(scope)
    end

    # Find a class definition, relative to the current namespace.
    def findclass(namespace, name)
        find_or_load namespace, name, @classtable
    end

    # Find a component definition, relative to the current namespace.
    def finddefine(namespace, name)
        find_or_load namespace, name, @definetable
    end

    # Attempt to find the requested object.  If it's not yet loaded,
    # attempt to load it.
    def find_or_load(namespace, name, table)
        if namespace == ""
            fullname = name.gsub("::", File::SEPARATOR)
        else
            fullname = ("%s::%s" % [namespace, name]).gsub("::", File::SEPARATOR)
        end
        
        # See if it's already loaded
        if result = fqfind(namespace, name, table)
            return result
        end

        if fullname == ""
            return nil
        end

        # Nope.  Try to load the module itself, to see if that
        # loads it.
        mod = fullname.scan(/^[\w-]+/).shift
        # We couldn't find it, so try to load the base module
        begin
            @parser.import(mod)
            Puppet.info "Autoloaded module %s" % mod
            if result = fqfind(namespace, name, table)
                return result
            end
        rescue Puppet::ImportError => detail
            # We couldn't load the module
        end


        # If they haven't specified a subclass, then there's no point in looking for
        # a separate file.
        if ! fullname.include?("/")
            return nil
        end

        # Nope.  Try to load the individual file
        begin
            @parser.import(fullname)
            Puppet.info "Autoloaded file %s from module %s" % [fullname, mod]
            if result = fqfind(namespace, name, table)
                return result
            end
        rescue Puppet::ImportError => detail
            # We couldn't load the file
        end

        return nil
    end

    # The recursive method used to actually look these objects up.
    def fqfind(namespace, name, table)
        namespace = namespace.downcase
        name = name.downcase
        if name =~ /^::/ or namespace == ""
            return table[name.sub(/^::/, '')]
        end
        ary = namespace.split("::")

        while ary.length > 0
            newname = (ary + [name]).join("::").sub(/^::/, '')
            if obj = table[newname]
                return obj
            end

            # Delete the second to last object, which reduces our namespace by one.
            ary.pop
        end

        # If we've gotten to this point without finding it, see if the name
        # exists at the top namespace
        if obj = table[name]
            return obj
        end

        return nil
    end

    # create our interpreter
    def initialize(hash)
        if @code = hash[:Code]
            @file = nil # to avoid warnings
        elsif ! @file = hash[:Manifest]
            devfail "You must provide code or a manifest"
        end

        if hash.include?(:UseNodes)
            @usenodes = hash[:UseNodes]
        else
            @usenodes = true
        end


        if Puppet[:ldapnodes]
            # Nodes in the file override nodes in ldap.
            @nodesource = :ldap
        elsif Puppet[:external_nodes] != "none"
            @nodesource = :external
        else
            # By default, we only search for parsed nodes.
            @nodesource = :code
        end

        @setup = false

        initparsevars()

        # Set it to either the value or nil.  This is currently only used
        # by the cfengine module.
        @classes = hash[:Classes] || []

        @local = hash[:Local] || false

        if hash.include?(:ForkSave)
            @forksave = hash[:ForkSave]
        else
            # This is just too dangerous right now.  Sorry, it's going
            # to have to be slow.
            @forksave = false
        end

        # The class won't always be defined during testing.
        if Puppet[:storeconfigs] 
            if Puppet.features.rails?
                Puppet::Rails.init
            else
                raise Puppet::Error, "Rails is missing; cannot store configurations"
            end
        end

        @files = []

        # Create our parser object
        parsefiles
    end

    # Initialize or reset the variables related to parsing.
    def initparsevars
        @classtable = {}
        @namespace = "main"

        @nodetable = {}

        @definetable = {}
    end

    # Find the ldap node, return the class list and parent node specially,
    # and everything else in a parameter hash.
    def ldapsearch(node)
        unless defined? @ldap and @ldap
            setup_ldap()
            unless @ldap
                Puppet.info "Skipping ldap source; no ldap connection"
                return nil
            end
        end

        filter = Puppet[:ldapstring]
        classattrs = Puppet[:ldapclassattrs].split("\s*,\s*")
        if Puppet[:ldapattrs] == "all"
            # A nil value here causes all attributes to be returned.
            search_attrs = nil
        else
            search_attrs = classattrs + Puppet[:ldapattrs].split("\s*,\s*")
        end
        pattr = nil
        if pattr = Puppet[:ldapparentattr]
            if pattr == ""
                pattr = nil
            else
                search_attrs << pattr unless search_attrs.nil?
            end
        end

        if filter =~ /%s/
            filter = filter.gsub(/%s/, node)
        end

        parent = nil
        classes = []
        parameters = nil

        found = false
        count = 0

        begin
            # We're always doing a sub here; oh well.
            @ldap.search(Puppet[:ldapbase], 2, filter, search_attrs) do |entry|
                found = true
                if pattr
                    if values = entry.vals(pattr)
                        if values.length > 1
                            raise Puppet::Error,
                                "Node %s has more than one parent: %s" %
                                [node, values.inspect]
                        end
                        unless values.empty?
                            parent = values.shift
                        end
                    end
                end

                classattrs.each { |attr|
                    if values = entry.vals(attr)
                        values.each do |v| classes << v end
                    end
                }

                parameters = entry.to_hash.inject({}) do |hash, ary|
                    if ary[1].length == 1
                        hash[ary[0]] = ary[1].shift
                    else
                        hash[ary[0]] = ary[1]
                    end
                    hash
                end
            end
        rescue => detail
            if count == 0
                # Try reconnecting to ldap
                @ldap = nil
                setup_ldap()
                retry
            else
                raise Puppet::Error, "LDAP Search failed: %s" % detail
            end
        end

        classes.flatten!

        if classes.empty?
            classes = nil
        end

        if parent or classes or parameters
            return parent, classes, parameters
        else
            return nil
        end
    end

    # Split an fq name into a namespace and name
    def namesplit(fullname)
        ary = fullname.split("::")
        n = ary.pop || ""
        ns = ary.join("::")
        return ns, n
    end

    # Create a new class, or merge with an existing class.
    def newclass(name, options = {})
        name = name.downcase
        if @definetable.include?(name)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" %
                name
        end
        code = options[:code]
        parent = options[:parent]

        # If the class is already defined, then add code to it.
        if other = @classtable[name]
            # Make sure the parents match
            if parent and other.parentclass and (parent != other.parentclass)
                @parser.error("Class %s is already defined at %s:%s; cannot redefine" % [name, other.file, other.line])
            end

            # This might be dangerous...
            if parent and ! other.parentclass
                other.parentclass = parent
            end

            # This might just be an empty, stub class.
            if code
                tmp = name
                if tmp == ""
                    tmp = "main"
                end
                
                Puppet.debug @parser.addcontext("Adding code to %s" % tmp)
                # Else, add our code to it.
                if other.code and code
                    other.code.children += code.children
                else
                    other.code ||= code
                end
            end
        else
            # Define it anew.
            # Note we're doing something somewhat weird here -- we're setting
            # the class's namespace to its fully qualified name.  This means
            # anything inside that class starts looking in that namespace first.
            args = {:namespace => name, :classname => name, :interp => self}
            args[:code] = code if code
            args[:parentclass] = parent if parent
            @classtable[name] = @parser.ast AST::HostClass, args
        end

        return @classtable[name]
    end

    # Create a new definition.
    def newdefine(name, options = {})
        name = name.downcase
        if @classtable.include?(name)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" %
                name
        end
        # Make sure our definition doesn't already exist
        if other = @definetable[name]
            @parser.error("%s is already defined at %s:%s; cannot redefine" % [name, other.file, other.line])
        end

        ns, whatever = namesplit(name)
        args = {
            :namespace => ns,
            :arguments => options[:arguments],
            :code => options[:code],
            :classname => name
        }

        [:code, :arguments].each do |param|
            args[param] = options[param] if options[param]
        end

        @definetable[name] = @parser.ast AST::Component, args
    end

    # Create a new node.  Nodes are special, because they're stored in a global
    # table, not according to namespaces.
    def newnode(names, options = {})
        names = [names] unless names.instance_of?(Array)
        names.collect do |name|
            name = name.to_s.downcase
            if other = @nodetable[name]
                @parser.error("Node %s is already defined at %s:%s; cannot redefine" % [other.name, other.file, other.line])
            end
            name = name.to_s if name.is_a?(Symbol)
            args = {
                :name => name,
            }
            if options[:code]
                args[:code] = options[:code]
            end
            if options[:parent]
                args[:parentclass] = options[:parent]
            end
            @nodetable[name] = @parser.ast(AST::Node, args)
            @nodetable[name].classname = name
            @nodetable[name].interp = self
            @nodetable[name]
        end
    end

    # Add a new file to be checked when we're checking to see if we should be
    # reparsed.
    def newfile(*files)
        files.each do |file|
            unless file.is_a? Puppet::Util::LoadedFile
                file = Puppet::Util::LoadedFile.new(file)
            end
            @files << file
        end
    end

    # Search for our node in the various locations.
    def nodesearch(*nodes)
        nodes = nodes.collect { |n| n.to_s.downcase }

        method = "nodesearch_%s" % @nodesource
        # Do an inverse sort on the length, so the longest match always
        # wins
        nodes.sort { |a,b| b.length <=> a.length }.each do |node|
            node = node.to_s if node.is_a?(Symbol)
            if obj = self.send(method, node)
                if obj.is_a?(AST::Node)
                    nsource = obj.file
                else
                    nsource = obj.source
                end
                Puppet.info "Found %s in %s" % [node, nsource]
                return obj
            end
        end

        # If they made it this far, we haven't found anything, so look for a
        # default node.
        unless nodes.include?("default")
            if defobj = self.nodesearch("default")
                Puppet.notice "Using default node for %s" % [nodes[0]]
                return defobj
            end
        end

        return nil
    end

    # See if our node was defined in the code.
    def nodesearch_code(name)
        @nodetable[name]
    end
    
    # Look for external node definitions.
    def nodesearch_external(name)
        return nil unless Puppet[:external_nodes] != "none"
        
        begin
            output = Puppet::Util.execute([Puppet[:external_nodes], name])
        rescue Puppet::ExecutionFailure => detail
            if $?.exitstatus == 1
                return nil
            else
                Puppet.err "Could not retrieve external node information for %s: %s" % [name, detail]
            end
            return nil
        end
        
        if output =~ /\A\s*\Z/ # all whitespace
            Puppet.debug "Empty response for %s from external node source" % name
            return nil
        end

        begin
            result = YAML.load(output).inject({}) { |hash, data| hash[symbolize(data[0])] = data[1]; hash }
        rescue => detail
            raise Puppet::Error, "Could not load external node results for %s: %s" % [name, detail]
        end

        node_args = {:source => "external node source", :name => name}
        set = false
        [:parameters, :classes].each do |param|
            if value = result[param]
                node_args[param] = value
                set = true
            end
        end

        if set
            return NodeDef.new(node_args)
        else
            return nil
        end
    end

    # Look for our node in ldap.
    def nodesearch_ldap(node)
        unless ary = ldapsearch(node)
            return nil
        end
        parent, classes, parameters = ary

        while parent
            parent, tmpclasses, tmpparams = ldapsearch(parent)
            classes += tmpclasses if tmpclasses
            tmpparams.each do |param, value|
                # Specifically test for whether it's set, so false values are handled
                # correctly.
                parameters[param] = value unless parameters.include?(param)
            end
        end

        return NodeDef.new(:name => node, :classes => classes, :source => "ldap", :parameters => parameters)
    end

    def parsedate
        parsefiles()
        @parsedate
    end

    # evaluate our whole tree
    def run(client, facts)
        # We have to leave this for after initialization because there
        # seems to be a problem keeping ldap open after a fork.
        unless @setup
            method = "setup_%s" % @nodesource.to_s
            if respond_to? method
                exceptwrap :type => Puppet::Error,
                        :message => "Could not set up node source %s" % @nodesource do
                    self.send(method)
                end
            end
        end
        parsefiles()

        # Evaluate all of the appropriate code.
        objects = evaluate(client, facts)

        # And return it all.
        return objects
    end

    # Connect to the LDAP Server
    def setup_ldap
        self.class.ldap = nil
        unless Puppet.features.ldap?
            Puppet.notice(
                "Could not set up LDAP Connection: Missing ruby/ldap libraries"
            )
            @ldap = nil
            return
        end

        begin
            @ldap = self.class.ldap()
        rescue => detail
            raise Puppet::Error, "Could not connect to LDAP: %s" % detail
        end
    end

    def scope
        return @scope
    end

    private

    # Check whether any of our files have changed.
    def checkfiles
        if @files.find { |f| f.changed?  }
            @parsedate = Time.now.to_i
        end
    end

    # Parse the files, generating our parse tree.  This automatically
    # reparses only if files are updated, so it's safe to call multiple
    # times.
    def parsefiles
        # First check whether there are updates to any non-puppet files
        # like templates.  If we need to reparse, this will get quashed,
        # but it needs to be done first in case there's no reparse
        # but there are other file changes.
        checkfiles()

        # Check if the parser should reparse.
        if @file
            if defined? @parser
                if stamp = @parser.reparse?
                    Puppet.notice "Reloading files"
                else
                    return false
                end
            end

            unless FileTest.exists?(@file)
                # If we've already parsed, then we're ok.
                if findclass("", "")
                    return
                else
                    raise Puppet::Error, "Manifest %s must exist" % @file
                end
            end
        end

        # Reset our parse tables.
        clear()

        # Create a new parser, just to keep things fresh.
        @parser = Puppet::Parser::Parser.new(self)
        if @code
            @parser.string = @code
        else
            @parser.file = @file
            # Mark when we parsed, so we can check freshness
            @parsedate = File.stat(@file).ctime.to_i
        end

        # Parsing stores all classes and defines and such in their
        # various tables, so we don't worry about the return.
        if @local
            @parser.parse
        else
            benchmark(:info, "Parsed manifest") do
                @parser.parse
            end
        end
        @parsedate = Time.now.to_i
    end

    # Store the configs into the database.
    def storeconfigs(hash)
        unless Puppet.features.rails?
            raise Puppet::Error,
                "storeconfigs is enabled but rails is unavailable"
        end

        unless ActiveRecord::Base.connected?
            Puppet::Rails.connect
        end

        # Fork the storage, since we don't need the client waiting
        # on that.  How do I avoid this duplication?
        if @forksave
            fork {
                # We store all of the objects, even the collectable ones
                benchmark(:info, "Stored configuration for #{hash[:name]}") do
                    # Try to batch things a bit, by putting them into
                    # a transaction
                    Puppet::Rails::Host.transaction do
                        Puppet::Rails::Host.store(hash)
                    end
                end
            }
        else
            begin
                # We store all of the objects, even the collectable ones
                benchmark(:info, "Stored configuration for #{hash[:name]}") do
                    Puppet::Rails::Host.transaction do
                        Puppet::Rails::Host.store(hash)
                    end
                end
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                Puppet.err "Could not store configs: %s" % detail.to_s
            end
        end
    end
end

# $Id$
