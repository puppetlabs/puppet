# I pulled this into a separate file, because I got
# tired of rebuilding the parser.rb file all the time.
class Puppet::Parser::Parser
    require 'puppet/parser/functions'

    ASTSet = Struct.new(:classes, :definitions, :nodes)

    # Define an accessor method for each table.  We hide the existence of
    # the struct.
    [:classes, :definitions, :nodes].each do |name|
        define_method(name) do
            @astset.send(name)
        end
    end

    AST = Puppet::Parser::AST

    attr_reader :version, :environment
    attr_accessor :files


    # Add context to a message; useful for error messages and such.
    def addcontext(message, obj = nil)
        obj ||= @lexer

        message += " on line %s" % obj.line
        if file = obj.file
            message += " in file %s" % file
        end

        return message
    end

    # Create an AST array out of all of the args
    def aryfy(*args)
        if args[0].instance_of?(AST::ASTArray)
            result = args.shift
            args.each { |arg|
                result.push arg
            }
        else
            result = ast AST::ASTArray, :children => args
        end

        return result
    end

    # Create an AST object, and automatically add the file and line information if
    # available.
    def ast(klass, hash = {})
        hash[:line] = @lexer.line unless hash.include?(:line)

        unless hash.include?(:file)
            if file = @lexer.file
                hash[:file] = file
            end
        end

        return klass.new(hash)
    end

    # The fully qualifed name, with the full namespace.
    def classname(name)
        [@lexer.namespace, name].join("::").sub(/^::/, '')
    end

    def clear
        initvars
    end

    # Raise a Parse error.
    def error(message)
        if brace = @lexer.expected
            message += "; expected '%s'"
        end
        except = Puppet::ParseError.new(message)
        except.line = @lexer.line
        if @lexer.file
            except.file = @lexer.file
        end

        raise except
    end

    def file
        @lexer.file
    end

    def file=(file)
        unless FileTest.exists?(file)
            unless file =~ /\.pp$/
                file = file + ".pp"
            end
            unless FileTest.exists?(file)
                raise Puppet::Error, "Could not find file %s" % file
            end
        end
        if @files.detect { |f| f.file == file }
            raise Puppet::AlreadyImportedError.new("Import loop detected")
        else
            @files << Puppet::Util::LoadedFile.new(file)
            @lexer.file = file
        end
    end

    # Find a class definition, relative to the current namespace.
    def findclass(namespace, name)
        fqfind namespace, name, classes
    end

    # Find a component definition, relative to the current namespace.
    def finddefine(namespace, name)
        fqfind namespace, name, definitions
    end

    # This is only used when nodes are looking up the code for their
    # parent nodes.
    def findnode(name)
        fqfind "", name, nodes
    end

    # The recursive method used to actually look these objects up.
    def fqfind(namespace, name, table)
        namespace = namespace.downcase
        name = name.to_s.downcase

        # If our classname is fully qualified or we have no namespace,
        # just try directly for the class, and return either way.
        if name =~ /^::/ or namespace == ""
            classname = name.sub(/^::/, '')
            self.load(classname) unless table[classname]
            return table[classname]
        end

        # Else, build our namespace up piece by piece, checking
        # for the class in each namespace.
        ary = namespace.split("::")

        while ary.length > 0
            newname = (ary + [name]).join("::").sub(/^::/, '')
            if obj = table[newname] or (self.load(newname) and obj = table[newname])
                return obj
            end

            # Delete the second to last object, which reduces our namespace by one.
            ary.pop
        end

        # If we've gotten to this point without finding it, see if the name
        # exists at the top namespace
        if obj = table[name] or (self.load(name) and obj = table[name])
            return obj
        end

        return nil
    end

    # Import our files.
    def import(file)
        if Puppet[:ignoreimport]
            return AST::ASTArray.new(:children => [])
        end
        # use a path relative to the file doing the importing
        if @lexer.file
            dir = @lexer.file.sub(%r{[^/]+$},'').sub(/\/$/, '')
        else
            dir = "."
        end
        if dir == ""
            dir = "."
        end
        result = ast AST::ASTArray

        # We can't interpolate at this point since we don't have any
        # scopes set up. Warn the user if they use a variable reference
        pat = file
        if pat.index("$")
            Puppet.warning(
               "The import of #{pat} contains a variable reference;" +
               " variables are not interpolated for imports " +
               "in file #{@lexer.file} at line #{@lexer.line}"
            )
        end
        files = Puppet::Module::find_manifests(pat, :cwd => dir, :environment => @environment)
        if files.size == 0
            raise Puppet::ImportError.new("No file(s) found for import " +
                                          "of '#{pat}'")
        end

        files.collect { |file|
            parser = Puppet::Parser::Parser.new(:astset => @astset, :environment => @environment)
            parser.files = self.files
            Puppet.debug("importing '%s'" % file)

            unless file =~ /^#{File::SEPARATOR}/
                file = File.join(dir, file)
            end
            begin
                parser.file = file
            rescue Puppet::AlreadyImportedError
                # This file has already been imported to just move on
                next
            end

            # This will normally add code to the 'main' class.
            parser.parse
        }
    end

    def initialize(options = {})
        @astset = options[:astset] || ASTSet.new({}, {}, {})
        @environment = options[:environment]
        initvars()
    end

    # Initialize or reset all of our variables.
    def initvars
        @lexer = Puppet::Parser::Lexer.new()
        @files = []
        @loaded = []
    end

    # Try to load a class, since we could not find it.
    def load(classname)
        return false if classname == ""
        filename = classname.gsub("::", File::SEPARATOR)

        # First try to load the top-level module
        mod = filename.scan(/^[\w-]+/).shift
        unless @loaded.include?(mod)
            @loaded << mod
            begin
                import(mod)
                Puppet.info "Autoloaded module %s" % mod
            rescue Puppet::ImportError => detail
                # We couldn't load the module
            end
        end

        return true if classes.include?(classname)

        unless @loaded.include?(filename)
            @loaded << filename
            # Then the individual file
            begin
                import(filename)
                Puppet.info "Autoloaded file %s from module %s" % [filename, mod]
            rescue Puppet::ImportError => detail
                # We couldn't load the file
            end
        end
        return classes.include?(classname)
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

        if definitions.include?(name)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" % name
        end
        code = options[:code]
        parent = options[:parent]

        # If the class is already defined, then add code to it.
        if other = @astset.classes[name]
            # Make sure the parents match
            if parent and other.parentclass and (parent != other.parentclass)
                error("Class %s is already defined at %s:%s; cannot redefine" % [name, other.file, other.line])
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
                
                Puppet.debug addcontext("Adding code to %s" % tmp)
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
            args = {:namespace => name, :classname => name, :parser => self}
            args[:code] = code if code
            args[:parentclass] = parent if parent
            @astset.classes[name] = ast AST::HostClass, args
        end

        return @astset.classes[name]
    end

    # Create a new definition.
    def newdefine(name, options = {})
        name = name.downcase
        if @astset.classes.include?(name)
            raise Puppet::ParseError, "Cannot redefine class %s as a definition" %
                name
        end
        # Make sure our definition doesn't already exist
        if other = @astset.definitions[name]
            error("%s is already defined at %s:%s; cannot redefine" % [name, other.file, other.line])
        end

        ns, whatever = namesplit(name)
        args = {
            :namespace => ns,
            :arguments => options[:arguments],
            :code => options[:code],
            :parser => self,
            :classname => name
        }

        [:code, :arguments].each do |param|
            args[param] = options[param] if options[param]
        end

        @astset.definitions[name] = ast AST::Definition, args
    end

    # Create a new node.  Nodes are special, because they're stored in a global
    # table, not according to namespaces.
    def newnode(names, options = {})
        names = [names] unless names.instance_of?(Array)
        names.collect do |name|
            name = name.to_s.downcase
            if other = @astset.nodes[name]
                error("Node %s is already defined at %s:%s; cannot redefine" % [other.name, other.file, other.line])
            end
            name = name.to_s if name.is_a?(Symbol)
            args = {
                :name => name,
                :parser => self
            }
            if options[:code]
                args[:code] = options[:code]
            end
            if options[:parent]
                args[:parentclass] = options[:parent]
            end
            @astset.nodes[name] = ast(AST::Node, args)
            @astset.nodes[name].classname = name
            @astset.nodes[name]
        end
    end

    def on_error(token,value,stack)
        if token == 0 # denotes end of file
            value = 'end of file'
        else
            value = "'%s'" % value
        end
        error = "Syntax error at %s" % [value]

        if brace = @lexer.expected
            error += "; expected '%s'" % brace
        end

        except = Puppet::ParseError.new(error)
        except.line = @lexer.line
        if @lexer.file
            except.file = @lexer.file
        end

        raise except
    end

    # how should I do error handling here?
    def parse(string = nil)
        if string
            self.string = string
        end
        begin
            main = yyparse(@lexer,:scan)
        rescue Racc::ParseError => except
            error = Puppet::ParseError.new(except)
            error.line = @lexer.line
            error.file = @lexer.file
            error.set_backtrace except.backtrace
            raise error
        rescue Puppet::ParseError => except
            except.line ||= @lexer.line
            except.file ||= @lexer.file
            raise except
        rescue Puppet::Error => except
            # and this is a framework error
            except.line ||= @lexer.line
            except.file ||= @lexer.file
            raise except
        rescue Puppet::DevError => except
            except.line ||= @lexer.line
            except.file ||= @lexer.file
            raise except
        rescue => except
            error = Puppet::DevError.new(except.message)
            error.line = @lexer.line
            error.file = @lexer.file
            error.set_backtrace except.backtrace
            raise error
        end
        if main
            # Store the results as the top-level class.
            newclass("", :code => main)
        end
        @version = Time.now.to_i
        return @astset
    ensure
        @lexer.clear
    end

    # See if any of the files have changed.
    def reparse?
        if file = @files.detect { |file| file.changed?  }
            return file.stamp
        else
            return false
        end
    end

    def string=(string)
        @lexer.string = string
    end

    # Add a new file to be checked when we're checking to see if we should be
    # reparsed.  This is basically only used by the TemplateWrapper to let the
    # parser know about templates that should be parsed.
    def watch_file(*files)
        files.each do |file|
            unless file.is_a? Puppet::Util::LoadedFile
                file = Puppet::Util::LoadedFile.new(file)
            end
            @files << file
        end
    end
end
