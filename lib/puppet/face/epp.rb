require 'puppet/face'
require 'puppet/pops'
require 'puppet/parser/files'
require 'puppet/file_system'

Puppet::Face.define(:epp, '0.0.1') do
  copyright "Puppet Inc.", 2014
  license   _("Apache 2 license; see COPYING")

  summary _("Interact directly with the EPP template parser/renderer.")

  action(:validate) do
    summary _("Validate the syntax of one or more EPP templates.")
    arguments _("[<template>] [<template> ...]")
    returns _("Nothing, or encountered syntax errors.")
    description <<-'EOT'
      This action validates EPP syntax without producing any output.

      When validating, multiple issues per file are reported up
      to the settings of max_error, and max_warnings. The processing
      stops after having reported issues for the first encountered file with errors
      unless the option --continue_on_error is given.

      Files can be given using the `modulename/template.epp` style to lookup the
      template from a module, or be given as a reference to a file. If the reference
      to a file can be resolved against a template in a module, the module version
      wins - in this case use an absolute path to reference the template file
      if the module version is not wanted.

      Exits with 0 if there were no validation errors.
    EOT

    option("--[no-]continue_on_error") do
      summary _("Whether or not to continue after errors are reported for a template.")
    end

    examples <<-'EOT'
      Validate the template 'template.epp' in module 'mymodule':

          $ puppet epp validate mymodule/template.epp

      Validate two arbitrary template files:

          $ puppet epp validate mymodule/template1.epp yourmodule/something.epp

        Validate a template somewhere in the file system:

            $ puppet epp validate /tmp/testing/template1.epp

         Validate a template against a file relative to the current directory:

           $ puppet epp validate template1.epp
           $ puppet epp validate ./template1.epp

      Validate from STDIN:

          $ cat template.epp | puppet epp validate

      Continue on error to see errors for all templates:

          $ puppet epp validate mymodule/template1.epp mymodule/template2.epp --continue_on_error
    EOT
    when_invoked do |*args|
      options = args.pop
      # pass a dummy node, as facts are not needed for validation
      options[:node] = Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}))
      compiler = create_compiler(options)

      status = true # no validation error yet
      files = args
      if files.empty?
        if not STDIN.tty?
          tmp = validate_template_string(STDIN.read)
          status &&= tmp
        else
          # This is not an error since a validate of all files in an empty
          # directory should not be treated as a failed validation.
          Puppet.notice _("No template specified. No action taken")
        end
      end

      missing_files = []
      files.each do |file|
        break if !status && !options[:continue_on_error]

        template_file = effective_template(file, compiler.environment)
        if template_file
          tmp = validate_template(template_file)
          status &&= tmp
        else
          missing_files << file
        end
      end
      if !missing_files.empty?
        raise Puppet::Error, _("One or more file(s) specified did not exist:\n%{missing_files_list}") %
            { missing_files_list: missing_files.map { |f| "   #{f}" }.join("\n") }
      else
        # Exit with 1 if there were errors
        raise Puppet::Error, _("Errors while validating epp") unless status
      end
    end
  end


  action (:dump) do
    summary _("Outputs a dump of the internal template parse tree for debugging")
    arguments "[--format <old|pn|json>] [--pretty] { -e <source> | [<templates> ...] } "
    returns _("A dump of the resulting AST model unless there are syntax or validation errors.")
    description <<-'EOT'
      The dump action parses and validates the EPP syntax and dumps the resulting AST model
      in a human readable (but not necessarily an easy to understand) format.

      The output format can be controlled using the --format <old|pn|json> where:
      * 'old' is the default, but now deprecated format which is not API.
      * 'pn' is the Puppet Extended S-Expression Notation.
      * 'json' outputs the same graph as 'pn' but with JSON syntax.

      The output will be "pretty printed" when the option --pretty is given together with --format 'pn' or 'json'. 
      This option has no effect on the 'old' format.

      The command accepts one or more templates (.epp) files, or an -e followed by the template
      source text. The given templates can be paths to template files, or references
      to templates in modules when given on the form <modulename>/<template-name>.epp.
      If no arguments are given, the stdin is read (unless it is attached to a terminal)

      If multiple templates are given, they are separated with a header indicating the
      name of the template. This can be suppressed with the option --no-header.
      The option --[no-]header has no effect when a single template is dumped.

      When debugging the epp parser itself, it may be useful to suppress the validation
      step with the `--no-validate` option to observe what the parser produced from the
      given source.

      This command ignores the --render-as setting/option.
    EOT

    option("--e " + _("<source>")) do
      default_to { nil }
      summary _("Dump one epp source expression given on the command line.")
    end

    option("--[no-]validate") do
      summary _("Whether or not to validate the parsed result, if no-validate only syntax errors are reported.")
    end

    option('--format ' + _('<old, pn, or json>')) do
      summary _("Get result in 'old' (deprecated format), 'pn' (new format), or 'json' (new format in JSON).")
    end

    option('--pretty') do
      summary _('Pretty print output. Only applicable together with --format pn or json')
    end

    option("--[no-]header") do
      summary _("Whether or not to show a file name header between files.")
    end

    when_invoked do |*args|
      require 'puppet/pops'
      options = args.pop
      # pass a dummy node, as facts are not needed for dump
      options[:node] = Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}))
      options[:header] = options[:header].nil? ? true : options[:header]
      options[:validate] = options[:validate].nil? ? true : options[:validate]

      compiler = create_compiler(options)

      # Print to a buffer since the face needs to return the resulting string
      # and the face API is "all or nothing"
      #
      buffer = StringIO.new

      if options[:e]
        buffer.print dump_parse(options[:e], 'command-line-string', options, false)
      elsif args.empty?
        if ! STDIN.tty?
          buffer.print dump_parse(STDIN.read, 'stdin', options, false)
        else
          raise Puppet::Error, _("No input to parse given on command line or stdin")
        end
      else
        templates, missing_files = args.reduce([[],[]]) do |memo, file|
          template_file = effective_template(file, compiler.environment)
          if template_file.nil?
            memo[1] << file
          else
            memo[0] << template_file
          end
          memo
        end

        show_filename = templates.count > 1
        templates.each do |file|
          buffer.print dump_parse(Puppet::FileSystem.read(file, :encoding => 'utf-8'), file, options, show_filename)
        end

        if !missing_files.empty?
          raise Puppet::Error, _("One or more file(s) specified did not exist:\n%{missing_files_list}") %
              { missing_files_list:  missing_files.collect { |f| "   #{f}" }.join("\n") }
        end
      end
      buffer.string
    end
  end

  action (:render) do
    summary _("Renders an epp template as text")
    arguments "-e <source> | [<templates> ...] "
    returns _("A rendered result of one or more given templates.")
    description <<-'EOT'
      This action renders one or more EPP templates.

      The command accepts one or more templates (.epp files), given the same way as templates
      are given to the puppet `epp` function (a full path, or a relative reference
      on the form '<modulename>/<template-name>.epp'), or as a relative path.args In case
      the given path matches both a modulename/template and a file, the template from
      the module is used.

      An inline_epp equivalent can also be performed by giving the template after
      an -e, or by piping the EPP source text to the command.

      Values to the template can be defined using the Puppet Language on the command
      line with `--values` or in a .pp or .yaml file referenced with `--values_file`. If
      specifying both the result is merged with --values having higher precedence.

      The --values option allows a Puppet Language sequence of expressions to be defined on the
      command line the same way as it may be given in a .pp file referenced with `--values_file`.
      It may set variable values (that become available in the template), and must produce
      either `undef` or a `Hash` of values (the hash may be empty). Producing `undef` simulates
      that the template is called without an arguments hash and thus only references
      variables in its outer scope. When a hash is given, a template is limited to seeing
      only the global scope. It is thus possible to simulate the different types of
      calls to the `epp` and `inline_epp` functions, with or without a given hash. Note that if
      variables are given, they are always available in this simulation - to test that the
      template only references variables given as arguments, produce a hash in --values or
      the --values_file, do not specify any variables that are not global, and
      turn on --strict_variables setting.

      If multiple templates are given, the same set of values are given to each template.
      If both --values and --value_file are used, the --values are merged on top of those given
      in the file.

      When multiple templates are rendered, a separating header is output between the templates
      showing the name of the template before the output. The header output can be turned off with
      `--no-header`. This also concatenates the template results without any added newline separators.

      Facts from the node where the command is being run are used by default.args Facts can be obtained
      for other nodes if they have called in, and reported their facts by using the `--node <nodename>`
      flag.

      Overriding node facts as well as additional facts can be given in a .yaml or .json file and referencing
      it with the --facts option. (Values can be obtained in yaml format directly from
      `facter`, or from puppet for a given node). Note that it is not possible to simulate the
      reserved variable name `$facts` in any other way.

      Note that it is not possible to set variables using the Puppet Language that have the same
      names as facts as this result in an error; "attempt to redefine a variable" since facts
      are set first.

      Exits with 0 if there were no validation errors. On errors, no rendered output is produced for
      that template file.

      When designing EPP templates, it is strongly recommended to define all template arguments
      in the template, and to give them in a hash when calling `epp` or `inline_epp` and to use
      as few global variables as possible, preferably only the $facts hash. This makes templates
      more free standing and are easier to reuse, and to test.
    EOT

    examples <<-'EOT'
      Render the template in module 'mymodule' called 'mytemplate.epp', and give it two arguments
      `a` and `b`:

          $ puppet epp render mymodule/mytemplate.epp --values '{a => 10, b => 20}'

      Render a template using an absolute path:

          $ puppet epp render /tmp/testing/mytemplate.epp --values '{a => 10, b => 20}'

      Render a template with data from a .pp file:

          $ puppet epp render /tmp/testing/mytemplate.epp --values_file mydata.pp

      Render a template with data from a .pp file and override one value on the command line:

          $ puppet epp render /tmp/testing/mytemplate.epp --values_file mydata.pp --values '{a=>10}'

      Render from STDIN:

          $ cat template.epp | puppet epp render --values '{a => 10, b => 20}'

      Set variables in a .pp file and render a template that uses variable references:

          # data.pp file
          $greeted = 'a global var'
          undef

          $ puppet epp render -e 'hello <%= $greeted %>' --values_file data.pp

      Render a template that outputs a fact:

          $ facter --yaml > data.yaml
          $ puppet epp render -e '<% $facts[osfamily] %>' --facts data.yaml
    EOT

    option("--node " + _("<node_name>")) do
      summary _("The name of the node for which facts are obtained. Defaults to facts for the local node.")
    end

    option("--e " + _("<source>")) do
      default_to { nil }
      summary _("Render one inline epp template given on the command line.")
    end

    option("--values " + _("<values_hash>")) do
      summary _("A Hash in Puppet DSL form given as arguments to the template being rendered.")
    end

    option("--values_file " + _("<pp_or_yaml_file>")) do
      summary _("A .pp or .yaml file that is processed to produce a hash of values for the template.")
    end

    option("--facts " + _("<facts_file>")) do
      summary _("A .yaml or .json file containing a hash of facts made available in $facts and $trusted")
    end

    option("--[no-]header") do
      summary _("Whether or not to show a file name header between rendered results.")
    end

    when_invoked do |*args|
      options = args.pop
      options[:header] = options[:header].nil? ? true : options[:header]

      compiler = create_compiler(options)
      compiler.with_context_overrides('For rendering epp') do

        # Print to a buffer since the face needs to return the resulting string
        # and the face API is "all or nothing"
        #
        buffer = StringIO.new
        status = true
        if options[:e]
          buffer.print render_inline(options[:e], compiler, options)
        elsif args.empty?
          if ! STDIN.tty?
            buffer.print render_inline(STDIN.read, compiler, options)
          else
            raise Puppet::Error, _("No input to process given on command line or stdin")
          end
        else
          show_filename = args.count > 1
          file_nbr = 0
          args.each do |file|
            begin
              buffer.print render_file(file, compiler, options, show_filename, file_nbr += 1)
            rescue Puppet::ParseError => detail
              Puppet.err(detail.message)
              status = false
            end
          end
        end
        raise Puppet::Error, _("error while rendering epp") unless status
        buffer.string
      end
    end
  end

  def dump_parse(source, filename, options, show_filename = true)
    output = ""
    evaluating_parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new
    begin
      if options[:validate]
        parse_result = evaluating_parser.parse_string(source, filename)
      else
        # side step the assert_and_report step
        parse_result = evaluating_parser.parser.parse_string(source)
      end
      if show_filename && options[:header]
        output << "--- #{filename}\n"
      end
      fmt = options[:format]
      if fmt.nil? || fmt == 'old'
        output << Puppet::Pops::Model::ModelTreeDumper.new.dump(parse_result) << "\n"
      else
        require 'puppet/pops/pn'
        pn = Puppet::Pops::Model::PNTransformer.transform(parse_result)
        case fmt
        when 'json'
          options[:pretty] ? JSON.pretty_unparse(pn.to_data) : JSON.dump(pn.to_data)
        else
          pn.format(options[:pretty] ? Puppet::Pops::PN::Indent.new('  ') : nil, output)
        end
      end
    rescue Puppet::ParseError => detail
      if show_filename
        Puppet.err("--- #{filename}")
      end
      Puppet.err(detail.message)
      ""
    end
  end

  def get_values(compiler, options)
    template_values = nil
    if values_file = options[:values_file]
      begin
        if values_file =~ /\.yaml$/
          template_values = YAML.load_file(values_file)
        elsif values_file =~ /\.pp$/
          evaluating_parser = Puppet::Pops::Parser::EvaluatingParser.new
          template_values = evaluating_parser.evaluate_file(compiler.topscope, values_file)
        else
          Puppet.err(_("Only .yaml or .pp can be used as a --values_file"))
        end
      rescue => e
        Puppet.err(_("Could not load --values_file %{error}") % { error: e.message })
      end
      if !(template_values.nil? || template_values.is_a?(Hash))
        Puppet.err(_("--values_file option must evaluate to a Hash or undef/nil, got: '%{template_class}'") % { template_class: template_values.class })
      end
    end

    if values = options[:values]
      evaluating_parser = Puppet::Pops::Parser::EvaluatingParser.new
      result = evaluating_parser.evaluate_string(compiler.topscope, values, 'values-hash')
      case result
      when nil
        template_values
      when Hash
        template_values.nil? ? result : template_values.merge(result)
      else
        Puppet.err(_("--values option must evaluate to a Hash or undef, got: '%{values_class}'") % { values_class: result.class })
      end
    else
      template_values
    end
  end

  def render_inline(epp_source, compiler, options)
    template_args = get_values(compiler, options)
    Puppet::Pops::Evaluator::EppEvaluator.inline_epp(compiler.topscope, epp_source, template_args)
  end

  def render_file(epp_template_name, compiler, options, show_filename, file_nbr)
    template_args = get_values(compiler, options)
    output = ""
    begin
      if show_filename && options[:header]
        output << "\n" unless file_nbr == 1
        output << "--- #{epp_template_name}\n"
      end
      # Change to an absolute file only if reference is to a an existing file. Note that an absolute file must be used
      # or the template must be found on the module path when calling the epp evaluator.
      template_file = Puppet::Parser::Files.find_template(epp_template_name, compiler.environment)
      if template_file.nil? && Puppet::FileSystem.exist?(epp_template_name)
        epp_template_name = File.expand_path(epp_template_name)
      end
      output << Puppet::Pops::Evaluator::EppEvaluator.epp(compiler.topscope, epp_template_name, compiler.environment, template_args)
    rescue Puppet::ParseError => detail
      Puppet.err("--- #{epp_template_name}") if show_filename
      raise detail
    end
    output
  end

  # @api private
  def validate_template(template)
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new()
    parser.parse_file(template)
    true
  rescue => detail
    Puppet.log_exception(detail)
    false
  end

  # @api private
  def validate_template_string(source)
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new()
    parser.parse_string(source, '<stdin>')
    true
  rescue => detail
    Puppet.log_exception(detail)
    false
  end

  # @api private
  def create_compiler(options)
    if options[:node]
      node = options[:node]
    else
      node = Puppet[:node_name_value]

      # If we want to lookup the node we are currently on
      # we must returning these settings to their default values
      Puppet.settings[:facts_terminus] = 'facter'
      Puppet.settings[:node_cache_terminus] = nil
    end

    unless node.is_a?(Puppet::Node)
      node = Puppet::Node.indirection.find(node)
      # Found node must be given the environment to use in some cases, use the one configured
      # or given on the command line
      node.environment = Puppet[:environment]
    end

    fact_file = options[:facts]

    if fact_file
      if fact_file.is_a?(Hash) # when used via the Face API
        given_facts = fact_file
      elsif fact_file.end_with?("json")
        given_facts = Puppet::Util::Json.load(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      else
        given_facts = YAML.load(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      end

      unless given_facts.instance_of?(Hash)
        raise _("Incorrect formatted data in %{fact_file} given via the --facts flag") % { fact_file: fact_file }
      end
      # It is difficult to add to or modify the set of facts once the node is created
      # as changes does not show up in parameters. Rather than manually patching up
      # a node and risking future regressions, a new node is created from scratch
      node = Puppet::Node.new(node.name, :facts => Puppet::Node::Facts.new("facts", node.facts.values.merge(given_facts)))
      node.environment = Puppet[:environment]
      node.merge(node.facts.values)
    end

    compiler = Puppet::Parser::Compiler.new(node)
    # configure compiler with facts and node related data
    # Set all global variables from facts
    compiler.send(:set_node_parameters)

    # pretend that the main class (named '') has been evaluated
    # since it is otherwise not possible to resolve top scope variables
    # using '::' when rendering. (There is no harm doing this for the other actions)
    #
    compiler.topscope.class_set('', compiler.topscope)
    compiler
  end

  # Produces the effective template file from a module/template or file reference
  # @api private
  def effective_template(file, env)
    template_file = Puppet::Parser::Files.find_template(file, env)
    if !template_file.nil?
      template_file
    elsif Puppet::FileSystem.exist?(file)
      file
    else
      nil
    end
  end

end
