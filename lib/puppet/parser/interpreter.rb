# The interepreter's job is to convert from a parsed file to the configuration
# for a given client.  It really doesn't do any work on its own, it just collects
# and calls out to other objects.

require 'puppet'
require 'timeout'
require 'puppet/parser/parser'
require 'puppet/parser/scope'

class Puppet::Parser::Interpreter
    include Puppet::Util

    Puppet.setdefaults("ldap",
        :ldapnodes => [false,
            "Whether to search for node configurations in LDAP."],
        :ldapssl => [false,
            "Whether SSL should be used when searching for nodes.
            Defaults to false because SSL usually requires certificates
            to be set up on the client side."],
        :ldaptls => [false,
            "Whether TLS should be used when searching for nodes.
            Defaults to false because TLS usually requires certificates
            to be set up on the client side."],
        :ldapserver => ["ldap",
            "The LDAP server.  Only used if ``ldapnodes`` is enabled."],
        :ldapport => [389,
            "The LDAP port.  Only used if ``ldapnodes`` is enabled."],
        :ldapstring => ["(&(objectclass=puppetClient)(cn=%s))",
            "The search string used to find an LDAP node."],
        :ldapattrs => ["puppetclass",
            "The LDAP attributes to use to define Puppet classes.  Values
            should be comma-separated."],
        :ldapparentattr => ["parentnode",
            "The attribute to use to define the parent node."],
        :ldapuser => ["",
            "The user to use to connect to LDAP.  Must be specified as a
            full DN."],
        :ldappassword => ["",
            "The password to use to connect to LDAP."],
        :ldapbase => ["",
            "The search base for LDAP searches.  It's impossible to provide
            a meaningful default here, although the LDAP libraries might
            have one already set.  Generally, it should be the 'ou=Hosts'
            branch under your main directory."]
    )

    Puppet.setdefaults(:puppetmaster,
        :storeconfigs => [false,
            "Whether to store each client's configuration.  This
             requires ActiveRecord from Ruby on Rails."]
    )

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

    def clear
        initparsevars
    end

    # Iteratively evaluate all of the objects.  This finds all fo the
    # objects that represent definitions and evaluates the definitions appropriately.
    # It also adds defaults and overrides as appropriate.
    def evaliterate(scope)
        count = 0
        begin
            timeout 300 do
                while ary = scope.unevaluated
                    ary.each do |resource|
                        resource.evaluate
                    end
                end
            end
        rescue Timeout::Error
            raise Puppet::DevError, "Got a timeout trying to evaluate all definitions"
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

        scope.host = facts["hostname"] || Facter.value("hostname")

        classes = @classes.dup

        # Okay, first things first.  Set our facts.
        scope.setfacts(facts)

        # Everyone will always evaluate the top-level class, if there is one.
        if klass = findclass("", "")
            # Set the source, so objects can tell where they were defined.
            scope.source = klass
            klass.safeevaluate :scope => scope, :nosubscope => true
        end

        # Next evaluate the node
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

        # Now perform the collections
        scope.collections.each do |coll|
            coll.evaluate
        end

        # Now finish everything.  This recursively calls finish on the
        # contained scopes and resources.
        scope.finish

        # Store everything.  We need to do this before translation, because
        # it operates on resources, not transobjects.
        if Puppet[:storeconfigs]
            args = {
                :resources => scope.resources,
                :name => client,
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
        if overrides.empty?
            return nil
        else
            fail Puppet::ParseError,
                "Could not find object(s) %s" % overrides.collect { |o|
                    o.ref
                }.join(", ")
        end
    end

    # Find a class definition, relative to the current namespace.
    def findclass(namespace, name)
        fqfind namespace, name, @classtable
    end

    # Find a component definition, relative to the current namespace.
    def finddefine(namespace, name)
        fqfind namespace, name, @definetable
    end

    # The recursive method used to actually look these objects up.
    def fqfind(namespace, name, table)
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

    # Create a new node, just from a list of names, classes, and an optional parent.
    def gennode(name, hash)
        facts = hash[:facts]
        classes = hash[:classes]
        parent = hash[:parentnode]
        arghash = {
            :name => name,
            :interp => self,
            :fqname => name
        }

        if (classes.is_a?(Array) and classes.empty?) or classes.nil?
            arghash[:code] = AST::ASTArray.new(:children => [])
        else
            classes = [classes] unless classes.is_a?(Array)

            classcode = @parser.ast(AST::ASTArray, :children => classes.collect do |klass|
                @parser.ast(AST::FlatString, :value => klass)
            end)

            # Now generate a function call.
            code = @parser.ast(AST::Function,
                :name => "include",
                :arguments => classcode,
                :ftype => :statement
            )

            arghash[:code] = code
        end

        if parent
            arghash[:parentclass] = parent
        end

        # Create the node
        return @parser.ast(AST::Node, arghash)
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

        # By default, we only search for parsed nodes.
        @nodesources = []

        if Puppet[:ldapnodes]
            # Nodes in the file override nodes in ldap.
            @nodesources << :ldap
        end

        if hash[:NodeSources]
            unless hash[:NodeSources].is_a?(Array)
                hash[:NodeSources] = [hash[:NodeSources]]
            end
            hash[:NodeSources].each do |src|
                if respond_to? "nodesearch_#{src.to_s}"
                    @nodesources << src.to_s.intern
                else
                    Puppet.warning "Node source '#{src}' not supported"
                end
            end
        end

        unless @nodesources.include?(:code)
            @nodesources << :code
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
        if Puppet[:storeconfigs] and defined? ActiveRecord::Base
            Puppet::Rails.init
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

    # Find the ldap node and extra the info, returning just
    # the critical data.
    def ldapsearch(node)
        unless defined? @ldap and @ldap
            setup_ldap()
            unless @ldap
                Puppet.info "Skipping ldap source; no ldap connection"
                return nil, []
            end
        end

        if node =~ /\./
            node = node.sub(/\..+/, '')
        end

        filter = Puppet[:ldapstring]
        attrs = Puppet[:ldapattrs].split("\s*,\s*")
        sattrs = attrs.dup
        pattr = nil
        if pattr = Puppet[:ldapparentattr]
            if pattr == ""
                pattr = nil
            else
                sattrs << pattr
            end
        end

        if filter =~ /%s/
            filter = filter.gsub(/%s/, node)
        end

        parent = nil
        classes = []

        found = false
        count = 0
        begin
            # We're always doing a sub here; oh well.
            @ldap.search(Puppet[:ldapbase], 2, filter, sattrs) do |entry|
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

                attrs.each { |attr|
                    if values = entry.vals(attr)
                        values.each do |v| classes << v end
                    end
                }
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

        return parent, classes
    end

    # Split an fq name into a namespace and name
    def namesplit(fullname)
        ary = fullname.split("::")
        n = ary.pop || ""
        ns = ary.join("::")
        return ns, n
    end

    # Create a new class, or merge with an existing class.
    def newclass(fqname, options = {})
        if @definetable.include?(fqname)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" %
                fqname
        end
        code = options[:code]
        parent = options[:parent]

        # If the class is already defined, then add code to it.
        if other = @classtable[fqname]
            # Make sure the parents match
            if parent and other.parentclass and (parent != other.parentclass)
                @parser.error @parser.addcontext("Class %s is already defined" % fqname) +
                    " with parent %s" % [fqname, other.parentclass]
            end

            # This might be dangerous...
            if parent and ! other.parentclass
                other.parentclass = parent
            end

            # This might just be an empty, stub class.
            if code
                tmp = fqname
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
            ns, name = namesplit(fqname)
            args = {:type => name, :namespace => ns, :fqname => fqname, :interp => self}
            args[:code] = code if code
            args[:parentclass] = parent if parent
            @classtable[fqname] = @parser.ast AST::HostClass, args
        end

        return @classtable[fqname]
    end

    # Create a new definition.
    def newdefine(fqname, options = {})
        if @classtable.include?(fqname)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" %
                fqname
        end
        # Make sure our definition doesn't already exist
        if other = @definetable[fqname]
            @parser.error @parser.addcontext(
                "%s is already defined at line %s" % [fqname, other.line],
                other
            )
        end

        ns, name = namesplit(fqname)
        args = {
            :type => name,
            :namespace => ns,
            :arguments => options[:arguments],
            :code => options[:code],
            :fqname => fqname
        }

        [:code, :arguments].each do |param|
            args[param] = options[param] if options[param]
        end

        @definetable[fqname] = @parser.ast AST::Component, args
    end

    # Create a new node.  Nodes are special, because they're stored in a global
    # table, not according to namespaces.
    def newnode(names, options = {})
        names = [names] unless names.instance_of?(Array)
        names.collect do |name|
            if other = @nodetable[name]
                @parser.error @parser.addcontext("Node %s is already defined" % [other.name], other)
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
            @nodetable[name].fqname = name
            @nodetable[name]
            @nodetable[name].interp = self
            @nodetable[name]
        end
    end

    # Add a new file to be checked when we're checking to see if we should be
    # reparsed.
    def newfile(*files)
        files.each do |file|
            unless file.is_a? Puppet::LoadedFile
                file = Puppet::LoadedFile.new(file)
            end
            @files << file
        end
    end

    # Search for our node in the various locations.
    def nodesearch(*nodes)
        # At this point, stop at the first source that defines
        # the node
        @nodesources.each do |source|
            method = "nodesearch_%s" % source
            if self.respond_to? method
                # Do an inverse sort on the length, so the longest match always
                # wins
                nodes.sort { |a,b| b.length <=> a.length }.each do |node|
                    node = node.to_s if node.is_a?(Symbol)
                    if obj = self.send(method, node)
                        nsource = obj.file || source
                        Puppet.info "Found %s in %s" % [node, nsource]
                        return obj
                    end
                end
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

    # Look for our node in ldap.
    def nodesearch_ldap(node)
        parent, classes = ldapsearch(node)
        if parent or classes
            args = {}
            args[:classes] = classes if classes
            args[:parentnode] = parent if parent
            return gennode(node, args)
        else
            return nil
        end
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
            @nodesources.each { |source|
                method = "setup_%s" % source.to_s
                if respond_to? method
                    exceptwrap :type => Puppet::Error,
                            :message => "Could not set up node source %s" % source do
                        self.send(method)
                    end
                end
            }
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
        begin
            require 'ldap'
        rescue LoadError
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

    # Iteratively make sure that every object in the scope tree is translated.
    def translate(scope)
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
        unless defined? ActiveRecord
            require 'puppet/rails'
            unless defined? ActiveRecord
                raise LoadError,
                    "storeconfigs is enabled but rails is unavailable"
            end
        end

        Puppet::Rails.init

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
            # We store all of the objects, even the collectable ones
            benchmark(:info, "Stored configuration for #{hash[:name]}") do
                Puppet::Rails::Host.transaction do
                    Puppet::Rails::Host.store(hash)
                end
            end
        end

        # Now that we've stored everything, we need to strip out
        # the collectable objects so that they are not sent on
        # to the host
        #hash[:objects].collectstrip!
    end
end

# $Id$
