require 'rdoc/generators/html_generator'
require 'puppet/util/rdoc/code_objects'
require 'digest/md5'

module Generators

  # This module holds all the classes needed to generate the HTML documentation
  # of a bunch of puppet manifests.
  #
  # It works by traversing all the code objects defined by the Puppet RDoc::Parser
  # and produces HTML counterparts objects that in turns are used by RDoc template engine
  # to produce the final HTML.
  #
  # It is also responsible of creating the whole directory hierarchy, and various index
  # files.
  #
  # It is to be noted that the whole system is built on top of ruby RDoc. As such there
  # is an implicit mapping of puppet entities to ruby entitites:
  #
  #         Puppet    =>    Ruby
  #         ------------------------
  #         Module          Module
  #         Class           Class
  #         Definition      Method
  #         Resource
  #         Node
  #         Plugin
  #         Fact

  MODULE_DIR = "modules"
  NODE_DIR = "nodes"
  PLUGIN_DIR = "plugins"

  # We're monkey patching RDoc markup to allow
  # lowercase class1::class2::class3 crossref hyperlinking
  module MarkUp
    alias :old_markup :markup

    def new_markup(str, remove_para=false)
      first = @markup.nil?
      res = old_markup(str, remove_para)
      if first and not @markup.nil?
        @markup.add_special(/\b([a-z]\w+(::\w+)*)/,:CROSSREF)
        # we need to call it again, since we added a rule
        res = old_markup(str, remove_para)
      end
      res
    end
    alias :markup :new_markup
  end

  # This is a specialized HTMLGenerator tailored to Puppet manifests
  class PuppetGenerator < HTMLGenerator

    def PuppetGenerator.for(options)
      AllReferences::reset
      HtmlMethod::reset

      if options.all_one_file
        PuppetGeneratorInOne.new(options)
      else
        PuppetGenerator.new(options)
      end
    end

    def initialize(options) #:not-new:
      @options    = options
      load_html_template
    end

    # loads our own html template file
    def load_html_template
        require 'puppet/util/rdoc/generators/template/puppet/puppet'
        extend RDoc::Page
    rescue LoadError
        $stderr.puts "Could not find Puppet template '#{template}'"
        exit 99
    end

    def gen_method_index
      # we don't generate an all define index
      # as the presentation is per module/per class
    end

    # This is the central method, it generates the whole structures
    # along with all the indices.
    def generate_html
      super
      gen_into(@nodes)
      gen_into(@plugins)
    end

    ##
    # Generate:
    #  the list of modules
    #  the list of classes and definitions of a specific module
    #  the list of all classes
    #  the list of nodes
    #  the list of resources
    def build_indices
      @allfiles = []
      @nodes = []
      @plugins = []

      # contains all the seen modules
      @modules = {}
      @allclasses = {}

      # remove unknown toplevels
      # it can happen that RDoc triggers a different parser for some files (ie .c, .cc or .h)
      # in this case RDoc generates a RDoc::TopLevel which we do not support in this generator
      # So let's make sure we don't generate html for those.
      @toplevels = @toplevels.select { |tl| tl.is_a? RDoc::PuppetTopLevel }

      # build the modules, classes and per modules classes and define list
      @toplevels.each do |toplevel|
        next unless toplevel.document_self
        file = HtmlFile.new(toplevel, @options, FILE_DIR)
        classes = []
        methods = []
        modules = []
        nodes = []

        # find all classes of this toplevel
        # store modules if we find one
        toplevel.each_classmodule do |k|
          generate_class_list(classes, modules, k, toplevel, CLASS_DIR)
        end

        # find all defines belonging to this toplevel
        HtmlMethod.all_methods.each do |m|
          # find parent module, check this method is not already
          # defined.
          if m.context.parent.toplevel === toplevel
            methods << m
          end
        end

        classes.each do |k|
          @allclasses[k.index_name] = k if !@allclasses.has_key?(k.index_name)
        end

        # generate nodes and plugins found
        classes.each do |k|
          if k.context.is_module?
            k.context.each_node do |name,node|
              nodes << HTMLPuppetNode.new(node, toplevel, NODE_DIR, @options)
              @nodes << nodes.last
            end
            k.context.each_plugin do |plugin|
              @plugins << HTMLPuppetPlugin.new(plugin, toplevel, PLUGIN_DIR, @options)
            end
            k.context.each_fact do |fact|
              @plugins << HTMLPuppetPlugin.new(fact, toplevel, PLUGIN_DIR, @options)
            end
          end
        end

        @files << file
        @allfiles << { "file" => file, "modules" => modules, "classes" => classes, "methods" => methods, "nodes" => nodes }
      end

      # scan all classes to create the childs references
      @allclasses.values.each do |klass|
        if superklass = klass.context.superclass
          if superklass = AllReferences[superklass] and (superklass.is_a?(HTMLPuppetClass) or superklass.is_a?(HTMLPuppetNode))
            superklass.context.add_child(klass.context)
          end
        end
      end

      @classes = @allclasses.values
    end

    # produce a class/module list of HTMLPuppetModule/HTMLPuppetClass
    # based on the code object traversal.
    def generate_class_list(classes, modules, from, html_file, class_dir)
      if from.is_module? and !@modules.has_key?(from.name)
        k = HTMLPuppetModule.new(from, html_file, class_dir, @options)
        classes << k
        @modules[from.name] = k
        modules << @modules[from.name]
      elsif from.is_module?
        modules << @modules[from.name]
      elsif !from.is_module?
        k = HTMLPuppetClass.new(from, html_file, class_dir, @options)
        classes << k
      end
      from.each_classmodule do |mod|
        generate_class_list(classes, modules, mod, html_file, class_dir)
      end
    end

    # generate all the subdirectories, modules, classes and files
    def gen_sub_directories
        super
        File.makedirs(MODULE_DIR)
        File.makedirs(NODE_DIR)
        File.makedirs(PLUGIN_DIR)
    rescue
        $stderr.puts $ERROR_INFO.message
        exit 1
    end

    # generate the index of modules
    def gen_file_index
      gen_top_index(@modules.values, 'All Modules', RDoc::Page::TOP_INDEX, "fr_modules_index.html")
    end

    # generate a top index
    def gen_top_index(collection, title, template, filename)
      template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
      res = []
      collection.sort.each do |f|
        if f.document_self
          res << { "classlist" => CGI.escapeHTML("#{MODULE_DIR}/fr_#{f.index_name}.html"), "module" => CGI.escapeHTML("#{CLASS_DIR}/#{f.index_name}.html"),"name" => CGI.escapeHTML(f.index_name) }
        end
      end

      values = {
        "entries"    => res,
        'list_title' => CGI.escapeHTML(title),
        'index_url'  => main_url,
        'charset'    => @options.charset,
        'style_url'  => style_url('', @options.css),
      }

      File.open(filename, "w") do |f|
        template.write_html_on(f, values)
      end
    end

    # generate the all classes index file and the combo index
    def gen_class_index
      gen_an_index(@classes, 'All Classes', RDoc::Page::CLASS_INDEX, "fr_class_index.html")
      @allfiles.each do |file|
        unless file['file'].context.file_relative_name =~ /\.rb$/

          gen_composite_index(
            file,
              RDoc::Page::COMBO_INDEX,

              "#{MODULE_DIR}/fr_#{file["file"].context.module_name}.html")
        end
      end
    end

    def gen_composite_index(collection, template, filename)\
      return if Puppet::FileSystem.exist?(filename)

      template = TemplatePage.new(RDoc::Page::FR_INDEX_BODY, template)
      res1 = []
      collection['classes'].sort.each do |f|
        if f.document_self
          res1 << { "href" => "../"+CGI.escapeHTML(f.path), "name" => CGI.escapeHTML(f.index_name) } unless f.context.is_module?
        end
      end

      res2 = []
      collection['methods'].sort.each do |f|
        res2 << { "href" => "../#{f.path}", "name" => f.index_name.sub(/\(.*\)$/,'') } if f.document_self
      end

      module_name = []
      res3 = []
      res4 = []
      collection['modules'].sort.each do |f|
        module_name << { "href" => "../"+CGI.escapeHTML(f.path), "name" => CGI.escapeHTML(f.index_name) }
        unless f.facts.nil?
          f.facts.each do |fact|
            res3 << {"href" => "../"+CGI.escapeHTML(AllReferences["PLUGIN(#{fact.name})"].path), "name" => CGI.escapeHTML(fact.name)}
          end
        end
        unless f.plugins.nil?
          f.plugins.each do |plugin|
            res4 << {"href" => "../"+CGI.escapeHTML(AllReferences["PLUGIN(#{plugin.name})"].path), "name" => CGI.escapeHTML(plugin.name)}
          end
        end
      end

      res5 = []
      collection['nodes'].sort.each do |f|
        res5 << { "href" => "../"+CGI.escapeHTML(f.path), "name" => CGI.escapeHTML(f.name) } if f.document_self
      end

      values = {
        "module" => module_name,
        "classes"    => res1,
        'classes_title' => CGI.escapeHTML("Classes"),
        'defines_title' => CGI.escapeHTML("Defines"),
        'facts_title' => CGI.escapeHTML("Custom Facts"),
        'plugins_title' => CGI.escapeHTML("Plugins"),
        'nodes_title' => CGI.escapeHTML("Nodes"),
        'index_url'  => main_url,
        'charset'    => @options.charset,
        'style_url'  => style_url('', @options.css),
      }

      values["defines"] = res2 if res2.size>0
      values["facts"] = res3 if res3.size>0
      values["plugins"] = res4 if res4.size>0
      values["nodes"] = res5 if res5.size>0

      File.open(filename, "w") do |f|
        template.write_html_on(f, values)
      end
    end

    # returns the initial_page url
    def main_url
      main_page = @options.main_page
      ref = nil
      if main_page
        ref = AllReferences[main_page]
        if ref
          ref = ref.path
        else
          $stderr.puts "Could not find main page #{main_page}"
        end
      end

      unless ref
        for file in @files
          if file.document_self and file.context.global
            ref = CGI.escapeHTML("#{CLASS_DIR}/#{file.context.module_name}.html")
            break
          end
        end
      end

      unless ref
        for file in @files
          if file.document_self and !file.context.global
            ref = CGI.escapeHTML("#{CLASS_DIR}/#{file.context.module_name}.html")
            break
          end
        end
      end

      unless ref
        $stderr.puts "Couldn't find anything to document"
        $stderr.puts "Perhaps you've used :stopdoc: in all classes"
        exit(1)
      end

      ref
    end

  end

  # This module is used to generate a referenced full name list of ContextUser
  module ReferencedListBuilder
    def build_referenced_list(list)
      res = []
      list.each do |i|
        ref = AllReferences[i.name] || @context.find_symbol(i.name)
        ref = ref.viewer if ref and ref.respond_to?(:viewer)
        name = i.respond_to?(:full_name) ? i.full_name : i.name
        h_name = CGI.escapeHTML(name)
        if ref and ref.document_self
          path = url(ref.path)
          res << { "name" => h_name, "aref" => path }
        else
          res << { "name" => h_name }
        end
      end
      res
    end
  end

  # This module is used to hold/generate a list of puppet resources
  # this is used in HTMLPuppetClass and HTMLPuppetNode
  module ResourceContainer
    def collect_resources
      list = @context.resource_list
      @resources = list.collect {|m| HTMLPuppetResource.new(m, self, @options) }
    end

    def build_resource_summary_list(path_prefix='')
      collect_resources unless @resources
      resources = @resources.sort
      res = []
      resources.each do |r|
        res << {
          "name" => CGI.escapeHTML(r.name),
          "aref" => CGI.escape(path_prefix)+"\#"+CGI.escape(r.aref)
        }
      end
      res
    end

    def build_resource_detail_list(section)
      outer = []
      resources = @resources.sort
      resources.each do |r|
        row = {}
        if r.section == section and r.document_self
          row["name"]        = CGI.escapeHTML(r.name)
          desc = r.description.strip
          row["m_desc"]      = desc unless desc.empty?
          row["aref"]        = r.aref
          row["params"]      = r.params
          outer << row
        end
      end
      outer
    end
  end

  class HTMLPuppetClass < HtmlClass
    include ResourceContainer, ReferencedListBuilder

    def value_hash
      super
      rl = build_resource_summary_list
      @values["resources"] = rl unless rl.empty?

      @context.sections.each do |section|
        secdata = @values["sections"].select { |s| s["secsequence"] == section.sequence }
        if secdata.size == 1
          secdata = secdata[0]

          rdl = build_resource_detail_list(section)
          secdata["resource_list"] = rdl unless rdl.empty?
        end
      end

      rl = build_require_list(@context)
      @values["requires"] = rl unless rl.empty?

      rl = build_realize_list(@context)
      @values["realizes"] = rl unless rl.empty?

      cl = build_child_list(@context)
      @values["childs"] = cl unless cl.empty?

      @values
    end

    def build_require_list(context)
      build_referenced_list(context.requires)
    end

    def build_realize_list(context)
      build_referenced_list(context.realizes)
    end

    def build_child_list(context)
      build_referenced_list(context.childs)
    end
  end

  class HTMLPuppetNode < ContextUser
    include ResourceContainer, ReferencedListBuilder

    attr_reader :path

    def initialize(context, html_file, prefix, options)
      super(context, options)

      @html_file = html_file
      @is_module = context.is_module?
      @values    = {}

      context.viewer = self

      if options.all_one_file
        @path = context.full_name
      else
        @path = http_url(context.full_name, prefix)
      end

      AllReferences.add("NODE(#{@context.full_name})", self)
    end

    def name
      @context.name
    end

    # return the relative file name to store this class in,
    # which is also its url
    def http_url(full_name, prefix)
      path = full_name.dup
      path.gsub!(/<<\s*(\w*)/) { "from-#$1" } if path['<<']
      File.join(prefix, path.split("::").collect { |p| Digest::MD5.hexdigest(p) }) + ".html"
    end

    def parent_name
      @context.parent.full_name
    end

    def index_name
      name
    end

    def write_on(f)
      value_hash

        template = TemplatePage.new(
          RDoc::Page::BODYINC,
            RDoc::Page::NODE_PAGE,

            RDoc::Page::METHOD_LIST)
      template.write_html_on(f, @values)
    end

    def value_hash
      class_attribute_values
      add_table_of_sections

      @values["charset"] = @options.charset
      @values["style_url"] = style_url(path, @options.css)

      d = markup(@context.comment)
      @values["description"] = d unless d.empty?

      ml = build_method_summary_list
      @values["methods"] = ml unless ml.empty?

      rl = build_resource_summary_list
      @values["resources"] = rl unless rl.empty?

      il = build_include_list(@context)
      @values["includes"] = il unless il.empty?

      rl = build_require_list(@context)
      @values["requires"] = rl unless rl.empty?

      rl = build_realize_list(@context)
      @values["realizes"] = rl unless rl.empty?

      cl = build_child_list(@context)
      @values["childs"] = cl unless cl.empty?

      @values["sections"] = @context.sections.map do |section|

        secdata = {
          "sectitle" => section.title,
          "secsequence" => section.sequence,
          "seccomment" => markup(section.comment)
        }

        al = build_alias_summary_list(section)
        secdata["aliases"] = al unless al.empty?

        co = build_constants_summary_list(section)
        secdata["constants"] = co unless co.empty?

        al = build_attribute_list(section)
        secdata["attributes"] = al unless al.empty?

        cl = build_class_list(0, @context, section)
        secdata["classlist"] = cl unless cl.empty?

        mdl = build_method_detail_list(section)
        secdata["method_list"] = mdl unless mdl.empty?

        rdl = build_resource_detail_list(section)
        secdata["resource_list"] = rdl unless rdl.empty?

        secdata
      end

      @values
    end

    def build_attribute_list(section)
      atts = @context.attributes.sort
      res = []
      atts.each do |att|
        next unless att.section == section
        if att.visibility == :public || att.visibility == :protected || @options.show_all
          entry = {
            "name"   => CGI.escapeHTML(att.name),
            "rw"     => att.rw,
            "a_desc" => markup(att.comment, true)
          }
          unless att.visibility == :public || att.visibility == :protected
            entry["rw"] << "-"
          end
          res << entry
        end
      end
      res
    end

    def class_attribute_values
      h_name = CGI.escapeHTML(name)

      @values["classmod"]  = "Node"
      @values["title"]     = CGI.escapeHTML("#{@values['classmod']}: #{h_name}")

      c = @context
      c = c.parent while c and !c.diagram

      @values["diagram"] = diagram_reference(c.diagram) if c && c.diagram

      @values["full_name"] = h_name

      parent_class = @context.superclass

      if parent_class
        @values["parent"] = CGI.escapeHTML(parent_class)

        if parent_name
          lookup = parent_name + "::#{parent_class}"
        else
          lookup = parent_class
        end
        lookup = "NODE(#{lookup})"
        parent_url = AllReferences[lookup] || AllReferences[parent_class]
        @values["par_url"] = aref_to(parent_url.path) if parent_url and parent_url.document_self
      end

      files = []
      @context.in_files.each do |f|
        res = {}
        full_path = CGI.escapeHTML(f.file_absolute_name)

        res["full_path"]     = full_path
        res["full_path_url"] = aref_to(f.viewer.path) if f.document_self

        res["cvsurl"] = cvs_url( @options.webcvs, full_path ) if @options.webcvs

        files << res
      end

      @values['infiles'] = files
    end

    def build_require_list(context)
      build_referenced_list(context.requires)
    end

    def build_realize_list(context)
      build_referenced_list(context.realizes)
    end

    def build_child_list(context)
      build_referenced_list(context.childs)
    end

    def <=>(other)
      self.name <=> other.name
    end
  end

  class HTMLPuppetModule < HtmlClass

    def initialize(context, html_file, prefix, options)
      super(context, html_file, prefix, options)
    end

    def value_hash
      @values = super

      fl = build_facts_summary_list
      @values["facts"] = fl unless fl.empty?

      pl = build_plugins_summary_list
      @values["plugins"] = pl unless pl.empty?

      nl = build_nodes_list(0, @context)
      @values["nodelist"] = nl unless nl.empty?

      @values
    end

    def build_nodes_list(level, context)
      res = ""
      prefix = "&nbsp;&nbsp;::" * level;

      context.nodes.sort.each do |node|
        if node.document_self
          res <<
          prefix <<
          "Node " <<
          href(url(node.viewer.path), "link", node.full_name) <<
          "<br />\n"
        end
      end
      res
    end

    def build_facts_summary_list
      potentially_referenced_list(context.facts) {|fn| ["PLUGIN(#{fn})"] }
    end

    def build_plugins_summary_list
      potentially_referenced_list(context.plugins) {|fn| ["PLUGIN(#{fn})"] }
    end

    def facts
      @context.facts
    end

    def plugins
      @context.plugins
    end

  end

  class HTMLPuppetPlugin < ContextUser
    attr_reader :path

    def initialize(context, html_file, prefix, options)
      super(context, options)

      @html_file = html_file
      @is_module = false
      @values    = {}

      context.viewer = self

      if options.all_one_file
        @path = context.full_name
      else
        @path = http_url(context.full_name, prefix)
      end

      AllReferences.add("PLUGIN(#{@context.full_name})", self)
    end

    def name
      @context.name
    end

    # return the relative file name to store this class in,
    # which is also its url
    def http_url(full_name, prefix)
      path = full_name.dup
      path.gsub!(/<<\s*(\w*)/) { "from-#$1" } if path['<<']
      File.join(prefix, path.split("::")) + ".html"
    end

    def parent_name
      @context.parent.full_name
    end

    def index_name
      name
    end

    def write_on(f)
      value_hash

        template = TemplatePage.new(
          RDoc::Page::BODYINC,
            RDoc::Page::PLUGIN_PAGE,

            RDoc::Page::PLUGIN_LIST)
      template.write_html_on(f, @values)
    end

    def value_hash
      attribute_values
      add_table_of_sections

      @values["charset"] = @options.charset
      @values["style_url"] = style_url(path, @options.css)

      d = markup(@context.comment)
      @values["description"] = d unless d.empty?

      if context.is_fact?
        unless context.confine.empty?
          res = {}
          res["type"] = context.confine[:type]
          res["value"] = context.confine[:value]
          @values["confine"] = [res]
        end
      else
        @values["type"] = context.type
      end

      @values["sections"] = @context.sections.map do |section|
        secdata = {
          "sectitle" => section.title,
          "secsequence" => section.sequence,
          "seccomment" => markup(section.comment)
        }
        secdata
      end

      @values
    end

    def attribute_values
      h_name = CGI.escapeHTML(name)

      if @context.is_fact?
        @values["classmod"]  = "Fact"
      else
        @values["classmod"]  = "Plugin"
      end
      @values["title"]     = "#{@values['classmod']}: #{h_name}"

      @values["full_name"] = h_name

      files = []
      @context.in_files.each do |f|
        res = {}
        full_path = CGI.escapeHTML(f.file_absolute_name)

        res["full_path"]     = full_path
        res["full_path_url"] = aref_to(f.viewer.path) if f.document_self

        res["cvsurl"] = cvs_url( @options.webcvs, full_path ) if @options.webcvs

        files << res
      end

      @values['infiles'] = files
    end

    def <=>(other)
      self.name <=> other.name
    end

  end

  class HTMLPuppetResource
    include MarkUp

    attr_reader :context

    @@seq = "R000000"

    def initialize(context, html_class, options)
      @context    = context
      @html_class = html_class
      @options    = options
      @@seq       = @@seq.succ
      @seq        = @@seq

      context.viewer = self

      AllReferences.add(name, self)
    end

    def as_href(from_path)
      if @options.all_one_file
        "##{path}"
      else
        HTMLGenerator.gen_url(from_path, path)
      end
    end

    def name
      @context.name
    end

    def section
      @context.section
    end

    def index_name
      "#{@context.name}"
    end

    def params
      @context.params
    end

    def parent_name
      if @context.parent.parent
        @context.parent.parent.full_name
      else
        nil
      end
    end

    def aref
      @seq
    end

    def path
      if @options.all_one_file
        aref
      else
        @html_class.path + "##{aref}"
      end
    end

    def description
      markup(@context.comment)
    end

    def <=>(other)
      @context <=> other.context
    end

    def document_self
      @context.document_self
    end

    def find_symbol(symbol, method=nil)
      res = @context.parent.find_symbol(symbol, method)
      res &&= res.viewer
    end

  end

  class PuppetGeneratorInOne < HTMLGeneratorInOne
    def gen_method_index
      gen_an_index(HtmlMethod.all_methods, 'Defines')
    end
  end

end
