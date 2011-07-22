# Puppet "parser" for the rdoc system
# The parser uses puppet parser and traverse the AST to instruct RDoc about
# our current structures. It also parses ruby files that could contain
# either custom facts or puppet plugins (functions, types...)

# rdoc mandatory includes
require "rdoc/code_objects"
require "puppet/util/rdoc/code_objects"
require "rdoc/tokenstream"

if ::RUBY_VERSION =~ /1.9/
	require "rdoc/markup/preprocess"
	require "rdoc/parser"
else
	require "rdoc/markup/simple_markup/preprocess"
	require "rdoc/parsers/parserfactory"
end

module RDoc

class Parser
  extend ParserFactory unless ::RUBY_VERSION =~ /1.9/

  SITE = "__site__"

  attr_accessor :input_file_name, :top_level

  # parser registration into RDoc
  parse_files_matching(/\.(rb|pp)$/)

  # called with the top level file
  def initialize(top_level, file_name, content, options, stats)
    @options = options
    @stats   = stats
    @input_file_name = file_name
    @top_level = PuppetTopLevel.new(top_level)
    @progress = $stderr unless options.quiet
  end

  # main entry point
  def scan
    environment = Puppet::Node::Environment.new
    @known_resource_types = environment.known_resource_types
    unless environment.known_resource_types.watching_file?(@input_file_name)
      Puppet.info "rdoc: scanning #{@input_file_name}"
      if @input_file_name =~ /\.pp$/
        @parser = Puppet::Parser::Parser.new(environment)
        @parser.file = @input_file_name
        @parser.parse.instantiate('').each do |type|
          @known_resource_types.add type
        end
      end
    end

    scan_top_level(@top_level)
    @top_level
  end

  # Due to a bug in RDoc, we need to roll our own find_module_named
  # The issue is that RDoc tries harder by asking the parent for a class/module
  # of the name. But by doing so, it can mistakenly use a module of same name
  # but from which we are not descendant.
  def find_object_named(container, name)
    return container if container.name == name
    container.each_classmodule do |m|
      return m if m.name == name
    end
    nil
  end

  # walk down the namespace and lookup/create container as needed
  def get_class_or_module(container, name)

    # class ::A -> A is in the top level
    if name =~ /^::/
      container = @top_level
    end

    names = name.split('::')

    final_name = names.pop
    names.each do |name|
      prev_container = container
      container = find_object_named(container, name)
      container ||= prev_container.add_class(PuppetClass, name, nil)
    end
    [container, final_name]
  end

  # split_module tries to find if +path+ belongs to the module path
  # if it does, it returns the module name, otherwise if we are sure
  # it is part of the global manifest path, "__site__" is returned.
  # And finally if this path couldn't be mapped anywhere, nil is returned.
  def split_module(path)
    # find a module
    fullpath = File.expand_path(path)
    Puppet.debug "rdoc: testing #{fullpath}"
    if fullpath =~ /(.*)\/([^\/]+)\/(?:manifests|plugins|lib)\/.+\.(pp|rb)$/
      modpath = $1
      name = $2
      Puppet.debug "rdoc: module #{name} into #{modpath} ?"
      Puppet::Module.modulepath.each do |mp|
        if File.identical?(modpath,mp)
          Puppet.debug "rdoc: found module #{name}"
          return name
        end
      end
    end
    if fullpath =~ /\.(pp|rb)$/
      # there can be paths we don't want to scan under modules
      # imagine a ruby or manifest that would be distributed as part as a module
      # but we don't want those to be hosted under <site>
      Puppet::Module.modulepath.each do |mp|
        # check that fullpath is a descendant of mp
        dirname = fullpath
        previous = dirname
        while (dirname = File.dirname(previous)) != previous
          previous = dirname
          return nil if File.identical?(dirname,mp)
        end
      end
    end
    # we are under a global manifests
    Puppet.debug "rdoc: global manifests"
    SITE
  end

  # create documentation for the top level +container+
  def scan_top_level(container)
    # use the module README as documentation for the module
    comment = ""
    readme = File.join(File.dirname(File.dirname(@input_file_name)), "README")
    comment = File.open(readme,"r") { |f| f.read } if FileTest.readable?(readme)
    look_for_directives_in(container, comment) unless comment.empty?

    # infer module name from directory
    name = split_module(@input_file_name)
    if name.nil?
      # skip .pp files that are not in manifests directories as we can't guarantee they're part
      # of a module or the global configuration.
      container.document_self = false
      return
    end

    Puppet.debug "rdoc: scanning for #{name}"

    container.module_name = name
    container.global=true if name == SITE

    @stats.num_modules += 1
    container, name  = get_class_or_module(container,name)
    mod = container.add_module(PuppetModule, name)
    mod.record_location(@top_level)
    mod.comment = comment

    if @input_file_name =~ /\.pp$/
      parse_elements(mod)
    elsif @input_file_name =~ /\.rb$/
      parse_plugins(mod)
    end
  end

  # create documentation for include statements we can find in +code+
  # and associate it with +container+
  def scan_for_include_or_require(container, code)
    code = [code] unless code.is_a?(Array)
    code.each do |stmt|
      scan_for_include_or_require(container,stmt.children) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

      if stmt.is_a?(Puppet::Parser::AST::Function) and ['include','require'].include?(stmt.name)
        stmt.arguments.each do |included|
          Puppet.debug "found #{stmt.name}: #{included}"
          container.send("add_#{stmt.name}",Include.new(included.to_s, stmt.doc))
        end
      end
    end
  end

  # create documentation for realize statements we can find in +code+
  # and associate it with +container+
  def scan_for_realize(container, code)
    code = [code] unless code.is_a?(Array)
    code.each do |stmt|
      scan_for_realize(container,stmt.children) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

      if stmt.is_a?(Puppet::Parser::AST::Function) and stmt.name == 'realize'
        stmt.arguments.each do |realized|
          Puppet.debug "found #{stmt.name}: #{realized}"
          container.add_realize(Include.new(realized.to_s, stmt.doc))
        end
      end
    end
  end

  # create documentation for global variables assignements we can find in +code+
  # and associate it with +container+
  def scan_for_vardef(container, code)
    code = [code] unless code.is_a?(Array)
    code.each do |stmt|
      scan_for_vardef(container,stmt.children) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

      if stmt.is_a?(Puppet::Parser::AST::VarDef)
        Puppet.debug "rdoc: found constant: #{stmt.name} = #{stmt.value}"
        container.add_constant(Constant.new(stmt.name.to_s, stmt.value.to_s, stmt.doc))
      end
    end
  end

  # create documentation for resources we can find in +code+
  # and associate it with +container+
  def scan_for_resource(container, code)
    code = [code] unless code.is_a?(Array)
    code.each do |stmt|
      scan_for_resource(container,stmt.children) if stmt.is_a?(Puppet::Parser::AST::ASTArray)

      if stmt.is_a?(Puppet::Parser::AST::Resource) and !stmt.type.nil?
        begin
          type = stmt.type.split("::").collect { |s| s.capitalize }.join("::")
          stmt.instances.each do |inst|
            title = inst.title.is_a?(Puppet::Parser::AST::ASTArray) ? inst.title.to_s.gsub(/\[(.*)\]/,'\1') : inst.title.to_s
            Puppet.debug "rdoc: found resource: #{type}[#{title}]"

            param = []
            inst.parameters.children.each do |p|
              res = {}
              res["name"] = p.param
              res["value"] = "#{p.value.to_s}" unless p.value.nil?

              param << res
            end

            container.add_resource(PuppetResource.new(type, title, stmt.doc, param))
          end
        rescue => detail
          raise Puppet::ParseError, "impossible to parse resource in #{stmt.file} at line #{stmt.line}: #{detail}"
        end
      end
    end
  end

  def resource_stmt_to_ref(stmt)
    type = stmt.type.split("::").collect { |s| s.capitalize }.join("::")
    title = stmt.title.is_a?(Puppet::Parser::AST::ASTArray) ? stmt.title.to_s.gsub(/\[(.*)\]/,'\1') : stmt.title.to_s

    param = stmt.params.children.collect do |p|
      {"name" => p.param, "value" => p.value.to_s}
    end
    PuppetResource.new(type, title, stmt.doc, param)
  end

  # create documentation for a class named +name+
  def document_class(name, klass, container)
    Puppet.debug "rdoc: found new class #{name}"
    container, name = get_class_or_module(container, name)

    superclass = klass.parent
    superclass = "" if superclass.nil? or superclass.empty?

    @stats.num_classes += 1
    comment = klass.doc
    look_for_directives_in(container, comment) unless comment.empty?
    cls = container.add_class(PuppetClass, name, superclass)
    # it is possible we already encountered this class, while parsing some namespaces
    # from other classes of other files. But at that time we couldn't know this class superclass
    # so, now we know it and force it.
    cls.superclass = superclass
    cls.record_location(@top_level)

    # scan class code for include
    code = klass.code.children if klass.code.is_a?(Puppet::Parser::AST::ASTArray)
    code ||= klass.code
    unless code.nil?
      scan_for_include_or_require(cls, code)
      scan_for_realize(cls, code)
      scan_for_resource(cls, code) if Puppet.settings[:document_all]
    end

    cls.comment = comment
  rescue => detail
    raise Puppet::ParseError, "impossible to parse class '#{name}' in #{klass.file} at line #{klass.line}: #{detail}"
  end

  # create documentation for a node
  def document_node(name, node, container)
    Puppet.debug "rdoc: found new node #{name}"
    superclass = node.parent
    superclass = "" if superclass.nil? or superclass.empty?

    comment = node.doc
    look_for_directives_in(container, comment) unless comment.empty?
    n = container.add_node(name, superclass)
    n.record_location(@top_level)

    code = node.code.children if node.code.is_a?(Puppet::Parser::AST::ASTArray)
    code ||= node.code
    unless code.nil?
      scan_for_include_or_require(n, code)
      scan_for_realize(n, code)
      scan_for_vardef(n, code)
      scan_for_resource(n, code) if Puppet.settings[:document_all]
    end

    n.comment = comment
  rescue => detail
    raise Puppet::ParseError, "impossible to parse node '#{name}' in #{node.file} at line #{node.line}: #{detail}"
  end

  # create documentation for a define
  def document_define(name, define, container)
    Puppet.debug "rdoc: found new definition #{name}"
    # find superclas if any
    @stats.num_methods += 1

    # find the parent
    # split define name by :: to find the complete module hierarchy
    container, name = get_class_or_module(container,name)

    # build up declaration
    declaration = ""
    define.arguments.each do |arg,value|
      declaration << "\$#{arg}"
      unless value.nil?
        declaration << " => "
        case value
        when Puppet::Parser::AST::Leaf
          declaration << "'#{value.value}'"
        when Puppet::Parser::AST::ASTArray
          declaration << "[#{value.children.collect { |v| "'#{v}'" }.join(", ")}]"
        else
          declaration << "#{value.to_s}"
        end
      end
      declaration << ", "
    end
    declaration.chop!.chop! if declaration.size > 1

    # register method into the container
    meth =  AnyMethod.new(declaration, name)
    meth.comment = define.doc
    container.add_method(meth)
    look_for_directives_in(container, meth.comment) unless meth.comment.empty?
    meth.params = "( #{declaration} )"
    meth.visibility = :public
    meth.document_self = true
    meth.singleton = false
  rescue => detail
    raise Puppet::ParseError, "impossible to parse definition '#{name}' in #{define.file} at line #{define.line}: #{detail}"
  end

  # Traverse the AST tree and produce code-objects node
  # that contains the documentation
  def parse_elements(container)
    Puppet.debug "rdoc: scanning manifest"

    @known_resource_types.hostclasses.values.sort { |a,b| a.name <=> b.name }.each do |klass|
      name = klass.name
      if klass.file == @input_file_name
        unless name.empty?
          document_class(name,klass,container)
        else # on main class document vardefs
          code = klass.code.children if klass.code.is_a?(Puppet::Parser::AST::ASTArray)
          code ||= klass.code
          scan_for_vardef(container, code) unless code.nil?
        end
      end
    end

    @known_resource_types.definitions.each do |name, define|
      if define.file == @input_file_name
        document_define(name,define,container)
      end
    end

    @known_resource_types.nodes.each do |name, node|
      if node.file == @input_file_name
        document_node(name.to_s,node,container)
      end
    end
  end

  # create documentation for plugins
  def parse_plugins(container)
    Puppet.debug "rdoc: scanning plugin or fact"
    if @input_file_name =~ /\/facter\/[^\/]+\.rb$/
      parse_fact(container)
    else
      parse_puppet_plugin(container)
    end
  end

  # this is a poor man custom fact parser :-)
  def parse_fact(container)
    comments = ""
    current_fact = nil
    File.open(@input_file_name) do |of|
      of.each do |line|
        # fetch comments
        if line =~ /^[ \t]*# ?(.*)$/
          comments += $1 + "\n"
        elsif line =~ /^[ \t]*Facter.add\(['"](.*?)['"]\)/
          current_fact = Fact.new($1,{})
          look_for_directives_in(container, comments) unless comments.empty?
          current_fact.comment = comments
          container.add_fact(current_fact)
          current_fact.record_location(@top_level)
          comments = ""
          Puppet.debug "rdoc: found custom fact #{current_fact.name}"
        elsif line =~ /^[ \t]*confine[ \t]*:(.*?)[ \t]*=>[ \t]*(.*)$/
          current_fact.confine = { :type => $1, :value => $2 } unless current_fact.nil?
        else # unknown line type
          comments =""
        end
      end
    end
  end

  # this is a poor man puppet plugin parser :-)
  # it doesn't extract doc nor desc :-(
  def parse_puppet_plugin(container)
    comments = ""
    current_plugin = nil

    File.open(@input_file_name) do |of|
      of.each do |line|
        # fetch comments
        if line =~ /^[ \t]*# ?(.*)$/
          comments += $1 + "\n"
        elsif line =~ /^[ \t]*newfunction[ \t]*\([ \t]*:(.*?)[ \t]*,[ \t]*:type[ \t]*=>[ \t]*(:rvalue|:lvalue)\)/
          current_plugin = Plugin.new($1, "function")
          container.add_plugin(current_plugin)
          look_for_directives_in(container, comments) unless comments.empty?
          current_plugin.comment = comments
          current_plugin.record_location(@top_level)
          comments = ""
          Puppet.debug "rdoc: found new function plugins #{current_plugin.name}"
        elsif line =~ /^[ \t]*Puppet::Type.newtype[ \t]*\([ \t]*:(.*?)\)/
          current_plugin = Plugin.new($1, "type")
          container.add_plugin(current_plugin)
          look_for_directives_in(container, comments) unless comments.empty?
          current_plugin.comment = comments
          current_plugin.record_location(@top_level)
          comments = ""
          Puppet.debug "rdoc: found new type plugins #{current_plugin.name}"
        elsif line =~ /module Puppet::Parser::Functions/
          # skip
        else # unknown line type
          comments =""
        end
      end
    end
  end

  # look_for_directives_in scans the current +comment+ for RDoc directives
  def look_for_directives_in(context, comment)
    preprocess = SM::PreProcess.new(@input_file_name, @options.rdoc_include)

    preprocess.handle(comment) do |directive, param|
      case directive
      when "stopdoc"
        context.stop_doc
        ""
      when "startdoc"
        context.start_doc
        context.force_documentation = true
        ""
      when "enddoc"
        #context.done_documenting = true
        #""
        throw :enddoc
      when "main"
        options = Options.instance
        options.main_page = param
        ""
      when "title"
        options = Options.instance
        options.title = param
        ""
      when "section"
        context.set_current_section(param, comment)
        comment.replace("") # 1.8 doesn't support #clear
        break
      else
        warn "Unrecognized directive '#{directive}'"
        break
      end
    end
    remove_private_comments(comment)
  end

  def remove_private_comments(comment)
    comment.gsub!(/^#--.*?^#\+\+/m, '')
    comment.sub!(/^#--.*/m, '')
  end
end
end
