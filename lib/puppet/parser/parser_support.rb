# I pulled this into a separate file, because I got
# tired of rebuilding the parser.rb file all the time.
class Puppet::Parser::Parser
  require 'puppet/parser/functions'
  require 'puppet/parser/files'
  require 'puppet/resource/type_collection'
  require 'puppet/resource/type_collection_helper'
  require 'puppet/resource/type'
  require 'monitor'

  AST = Puppet::Parser::AST

  include Puppet::Resource::TypeCollectionHelper

  attr_reader :version, :environment
  attr_accessor :files

  attr_accessor :lexer

  # Add context to a message; useful for error messages and such.
  def addcontext(message, obj = nil)
    obj ||= @lexer

    message += " on line #{obj.line}"
    if file = obj.file
      message += " in file #{file}"
    end

    message
  end

  # Create an AST array containing a single element
  def aryfy(arg)
    ast AST::ASTArray, :children => [arg]
  end

  # Create an AST object, and automatically add the file and line information if
  # available.
  def ast(klass, hash = {})
    klass.new ast_context(klass.use_docs, hash[:line]).merge(hash)
  end

  def ast_context(include_docs = false, ast_line = nil)
    result = {
      :line => ast_line || lexer.line,
      :file => lexer.file
    }
    result[:doc] = lexer.getcomment(result[:line]) if include_docs
    result
  end

  # The fully qualifed name, with the full namespace.
  def classname(name)
    [@lexer.namespace, name].join("::").sub(/^::/, '')
  end

  def clear
    initvars
  end

  # Raise a Parse error.
  def error(message, options = {})
    if brace = @lexer.expected
      message += "; expected '%s'"
    end
    except = Puppet::ParseError.new(message)
    except.line = options[:line] || @lexer.line
    except.file = options[:file] || @lexer.file

    raise except
  end

  def file
    @lexer.file
  end

  def file=(file)
    unless FileTest.exist?(file)
      unless file =~ /\.pp$/
        file = file + ".pp"
      end
    end
    raise Puppet::AlreadyImportedError, "Import loop detected" if known_resource_types.watching_file?(file)

    watch_file(file)
    @lexer.file = file
  end

  [:hostclass, :definition, :node, :nodes?].each do |method|
    define_method(method) do |*args|
      known_resource_types.send(method, *args)
    end
  end

  def find_hostclass(namespace, name)
    known_resource_types.find_hostclass(namespace, name)
  end

  def find_definition(namespace, name)
    known_resource_types.find_definition(namespace, name)
  end

  def import(file)
    known_resource_types.loader.import(file, @lexer.file)
  end

  def initialize(env)
    # The environment is needed to know how to find the resource type collection.
    @environment = env.is_a?(String) ? Puppet::Node::Environment.new(env) : env
    initvars
  end

  # Initialize or reset all of our variables.
  def initvars
    @lexer = Puppet::Parser::Lexer.new
  end

  # Split an fq name into a namespace and name
  def namesplit(fullname)
    ary = fullname.split("::")
    n = ary.pop || ""
    ns = ary.join("::")
    return ns, n
  end

  def on_error(token,value,stack)
    if token == 0 # denotes end of file
      value = 'end of file'
    else
      value = "'#{value[:value]}'"
    end
    error = "Syntax error at #{value}"

    if brace = @lexer.expected
      error += "; expected '#{brace}'"
    end

    except = Puppet::ParseError.new(error)
    except.line = @lexer.line
    except.file = @lexer.file if @lexer.file

    raise except
  end

  # how should I do error handling here?
  def parse(string = nil)
    if self.file =~ /\.rb$/
      main = parse_ruby_file
    else
      self.string = string if string
      begin
        @yydebug = false
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
    end
    # Store the results as the top-level class.
    return Puppet::Parser::AST::Hostclass.new('', :code => main)
  ensure
    @lexer.clear
  end

  def parse_ruby_file
    # Execute the contents of the file inside its own "main" object so
    # that it can call methods in the resource type API.
    main_object = Puppet::DSL::ResourceTypeAPI.new
    main_object.instance_eval(File.read(self.file))

    # Then extract any types that were created.
    Puppet::Parser::AST::ASTArray.new :children => main_object.instance_eval { @__created_ast_objects__ }
  end

  def string=(string)
    @lexer.string = string
  end

  def version
    known_resource_types.version
  end

  # Add a new file to be checked when we're checking to see if we should be
  # reparsed.  This is basically only used by the TemplateWrapper to let the
  # parser know about templates that should be parsed.
  def watch_file(filename)
    known_resource_types.watch_file(filename)
  end
end
