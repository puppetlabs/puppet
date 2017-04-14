# Functionality common to both our RDoc version 1 and 2 parsers.
module RDoc::PuppetParserCore

  SITE = "__site__"

  def self.included(base)
    base.class_eval do
      attr_accessor :input_file_name, :top_level

      # parser registration into RDoc
      parse_files_matching(/\.(rb)$/)
    end
  end

  # called with the top level file
  def initialize(top_level, file_name, body, options, stats)
    @options = options
    @stats   = stats
    @input_file_name = file_name
    @top_level = top_level
    @top_level.extend(RDoc::PuppetTopLevel)
    @progress = $stderr unless options.quiet
  end

  # main entry point
  def scan
    environment = Puppet.lookup(:current_environment)
    scan_top_level(@top_level, environment)
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
    names.each do |n|
      prev_container = container
      container = find_object_named(container, n)
      container ||= prev_container.add_class(RDoc::PuppetClass, n, nil)
    end
    [container, final_name]
  end

  # split_module tries to find if +path+ belongs to the module path
  # if it does, it returns the module name, otherwise if we are sure
  # it is part of the global manifest path, "__site__" is returned.
  # And finally if this path couldn't be mapped anywhere, nil is returned.
  def split_module(path, environment)
    # find a module
    fullpath = File.expand_path(path)
    Puppet.debug "rdoc: testing #{fullpath}"
    if fullpath =~ /(.*)\/([^\/]+)\/(?:manifests|plugins|lib)\/.+\.(rb)$/
      modpath = $1
      name = $2
      Puppet.debug "rdoc: module #{name} into #{modpath} ?"
      environment.modulepath.each do |mp|
        if File.identical?(modpath,mp)
          Puppet.debug "rdoc: found module #{name}"
          return name
        end
      end
    end
    if fullpath =~ /\.(rb)$/
      # there can be paths we don't want to scan under modules
      # imagine a ruby or manifest that would be distributed as part as a module
      # but we don't want those to be hosted under <site>
      environment.modulepath.each do |mp|
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
  def scan_top_level(container, environment)
    # use the module README as documentation for the module
    comment = ""
    %w{README README.rdoc}.each do |rfile|
      readme = File.join(File.dirname(File.dirname(@input_file_name)), rfile)
      # module README should be UTF-8, not default system encoding
      comment = File.open(readme,"r:UTF-8") { |f| f.read } if FileTest.readable?(readme)
    end
    look_for_directives_in(container, comment) unless comment.empty?

    # infer module name from directory
    name = split_module(@input_file_name, environment)
    if name.nil?
      # skip .pp files that are not in manifests directories as we can't guarantee they're part
      # of a module or the global configuration.
      # PUP-3638, keeping this while it should have no effect since no .pp files are now processed
      container.document_self = false
      return
    end

    Puppet.debug "rdoc: scanning for #{name}"

    container.module_name = name
    container.global=true if name == SITE

    container, name  = get_class_or_module(container,name)
    mod = container.add_module(RDoc::PuppetModule, name)
    mod.record_location(@top_level)
    mod.add_comment(comment, @input_file_name)

    if @input_file_name =~ /\.rb$/
      parse_plugins(mod)
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
    parsed_facts = []
    File.open(@input_file_name) do |of|
      of.each do |line|
        # fetch comments
        if line =~ /^[ \t]*# ?(.*)$/
          comments += $1 + "\n"
        elsif line =~ /^[ \t]*Facter.add\(['"](.*?)['"]\)/
          current_fact = RDoc::Fact.new($1,{})
          look_for_directives_in(container, comments) unless comments.empty?
          current_fact.comment = comments
          parsed_facts << current_fact
          comments = ""
          Puppet.debug "rdoc: found custom fact #{current_fact.name}"
        elsif line =~ /^[ \t]*confine[ \t]*:(.*?)[ \t]*=>[ \t]*(.*)$/
          current_fact.confine = { :type => $1, :value => $2 } unless current_fact.nil?
        else # unknown line type
          comments =""
        end
      end
    end
    parsed_facts.each do |f|
      container.add_fact(f)
      f.record_location(@top_level)
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
        elsif line =~ /^[ \t]*(?:Puppet::Parser::Functions::)?newfunction[ \t]*\([ \t]*:(.*?)[ \t]*,[ \t]*:type[ \t]*=>[ \t]*(:rvalue|:lvalue)/
          current_plugin = RDoc::Plugin.new($1, "function")
          look_for_directives_in(container, comments) unless comments.empty?
          current_plugin.comment = comments
          current_plugin.record_location(@top_level)
          container.add_plugin(current_plugin)
          comments = ""
          Puppet.debug "rdoc: found new function plugins #{current_plugin.name}"
        elsif line =~ /^[ \t]*Puppet::Type.newtype[ \t]*\([ \t]*:(.*?)\)/
          current_plugin = RDoc::Plugin.new($1, "type")
          look_for_directives_in(container, comments) unless comments.empty?
          current_plugin.comment = comments
          current_plugin.record_location(@top_level)
          container.add_plugin(current_plugin)
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

  # New instance of the appropriate PreProcess for our RDoc version.
  def create_rdoc_preprocess
    raise(NotImplementedError, "This method must be overwritten for whichever version of RDoc this parser is working with")
  end

  # look_for_directives_in scans the current +comment+ for RDoc directives
  def look_for_directives_in(context, comment)
    preprocess = create_rdoc_preprocess

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
