# I pulled this into a separate file, because I got
# tired of rebuilding the parser.rb file all the time.
require 'forwardable'

class Puppet::Parser::Parser
  extend Forwardable

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

  # Create an AST block containing a single element
  def block(arg)
    ast AST::BlockExpression, :children => [arg]
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
    if @lexer.expected
      message += "; expected '%s'"
    end
    except = Puppet::ParseError.new(message)
    except.line = options[:line] || @lexer.line
    except.file = options[:file] || @lexer.file

    raise except
  end

  def_delegators :@lexer, :file, :string=

  def file=(file)
    unless Puppet::FileSystem.exist?(file)
      unless file =~ /\.pp$/
        file = file + ".pp"
      end
    end
    raise Puppet::AlreadyImportedError, "Import loop detected for #{file}" if known_resource_types.watching_file?(file)

    watch_file(file)
    @lexer.file = file
  end

  def_delegators :known_resource_types, :hostclass, :definition, :node, :nodes?
  def_delegators :known_resource_types, :find_hostclass, :find_definition
  def_delegators :known_resource_types, :watch_file, :version

  def import(file)
    deprecation_location_text =
    if @lexer.file && @lexer.line
      " at #{@lexer.file}:#{@lexer.line}"
    elsif @lexer.file
      " in file #{@lexer.file}"
    elsif @lexer.line
      " at #{@lexer.line}"
    end

    Puppet.deprecation_warning("The use of 'import' is deprecated#{deprecation_location_text}. See http://links.puppetlabs.com/puppet-import-deprecation")
    if @lexer.file
      # use a path relative to the file doing the importing
      dir = File.dirname(@lexer.file)
    else
      # otherwise assume that everything needs to be from where the user is
      # executing this command. Normally, this would be in a "puppet apply -e"
      dir = Dir.pwd
    end

    known_resource_types.loader.import(file, dir)
  end

  def initialize(env)
    @environment = env
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
      rescue Puppet::ParseError => except
        except.line ||= @lexer.line
        except.file ||= @lexer.file
        except.pos ||= @lexer.pos
        raise except
      rescue => except
        raise Puppet::ParseError.new(except.message, @lexer.file, @lexer.line, nil, except)
      end
    end
    # Store the results as the top-level class.
    return Puppet::Parser::AST::Hostclass.new('', :code => main)
  ensure
    @lexer.clear
  end

  def parse_ruby_file
    Puppet.deprecation_warning("Use of the Ruby DSL is deprecated.")

    # Execute the contents of the file inside its own "main" object so
    # that it can call methods in the resource type API.
    main_object = Puppet::DSL::ResourceTypeAPI.new
    main_object.instance_eval(File.read(self.file))

    # Then extract any types that were created.
    Puppet::Parser::AST::BlockExpression.new :children => main_object.instance_eval { @__created_ast_objects__ }
  end
end
