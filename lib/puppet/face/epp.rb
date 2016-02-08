require 'puppet/face'
require 'puppet/pops'
require 'puppet/parser/files'
require 'puppet/file_system'

Puppet::Face.define(:epp, '0.0.1') do
  copyright "Puppet Labs", 2014
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with the EPP template parser/renderer."

  action(:validate) do
    summary "Validate the syntax of one or more EPP templates."
    arguments "[<template>] [<template> ...]"
    returns "Nothing, or encountered syntax errors."
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
      summary "Whether or not to continue after errors are reported for a template."
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
      compiler = create_compiler(options)

      status = true # no validation error yet
      files = args
      if files.empty?
        if not STDIN.tty?
          tmp = validate_template_string(STDIN.read)
          status &&= tmp
        else
          # This is not an error since a validate of all files in an empty
          # directry should not be treated as a failed validation.
          Puppet.notice "No template specified. No action taken"
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
        raise Puppet::Error, "One or more file(s) specified did not exist:\n" + missing_files.map { |f| "   #{f}" }.join("\n")
      else
        # Exit with 1 if there were errors
        raise Puppet::Error, "Errors while validating epp" unless status
      end
    end
  end


  action (:dump) do
    summary "Outputs a dump of the internal template parse tree for debugging"
    arguments "-e <source> | [<templates> ...] "
    returns "A dump of the resulting AST model unless there are syntax or validation errors."
    description <<-'EOT'
      The dump action parses and validates the EPP syntax and dumps the resulting AST model
      in a human readable (but not necessarily an easy to understand) format.
      The output format of the dumped tree is intended for epp parser debugging purposes
      and is not API, and may thus change between versions without deprecation warnings.

      The command accepts one or more templates (.epp) files, or an -e followed by the template
      source text. The given templates can be paths to template files, or references
      to templates in modules when given on the form <modulename>/<template-name>.epp.
      If no arguments are given, the stdin is read (unless it is attached to a terminal)

      If multiple templates are given, they are separated with a header indicating the
      name of the template. This can be surpressed with the option --no-header.
      The option --[no-]header has no effect whe a single template is dumped.

      When debugging the epp parser itself, it may be useful to surpress the valiation
      step with the `--no-validate` option to observe what the parser produced from the
      given source.

      This command ignores the --render-as setting/option.
    EOT

    option("--e <source>") do
      default_to { nil }
      summary "Dump one epp source expression given on the command line."
    end

    option("--[no-]validate") do
      summary "Whether or not to validate the parsed result, if no-validate only syntax errors are reported."
    end

    option("--[no-]header") do
      summary "Whether or not to show a file name header between files."
    end

    when_invoked do |*args|
      require 'puppet/pops'
      options = args.pop
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
          raise Puppet::Error, "No input to parse given on command line or stdin"
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
        dumps = templates.each do |file|
          buffer.print dump_parse(Puppet::FileSystem.read(file, :encoding => 'utf-8'), file, options, show_filename)
        end

        if !missing_files.empty?
          raise Puppet::Error, "One or more file(s) specified did not exist:\n" + missing_files.collect { |f| "   #{f}" }.join("\n")
        end
      end
      buffer.string
    end
  end

  action (:render) do
    summary "Renders an epp template as text"
    arguments "-e <source> | [<templates> ...] "
    returns "A rendered result of one or more given templates."
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

      Facts for the simulated node can be feed to the rendering process by referencing a .yaml file
      with facts using the --facts option. (Values can be obtained in yaml format directly from
      `facter`, or from puppet for a given node). Note that it is not possible to simulate the
      reserved variable name `$facts` in any other way.

      Note that it is not possible to set variables using the Puppet Language that have the same
      names as facts as this result in an error; "attempt to redefine a variable" since facts
      are set first.

      Exits with 0 if there were no validation errors. On errors, no rendered output is produced for
      that template file.

      When designing EPP templates, it is strongly recommended to define all template arguments
      in the template, and to give them in a hash when calling `epp` or `inline_epp` and to use
      as few global variables as possible, preferrably only the $facts hash. This makes templates
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

    option "--e <source>" do
      default_to { nil }
      summary "Render one inline epp template given on the command line."
    end

    option("--values <values_hash>") do
      summary "A Hash in Puppet DSL form given as arguments to the template being rendered."
    end

    option("--values_file <pp_or_yaml_file>") do
      summary "A .pp or .yaml file that is processed to produce a hash of values for the template."
    end

    option("--facts <yaml_file>") do
      summary "A .yaml file containing a hash of facts made available in $facts"
    end

    option("--[no-]header") do
      summary "Whether or not to show a file name header between rendered results."
    end

    when_invoked do |*args|
      options = args.pop
      options[:header] = options[:header].nil? ? true : options[:header]

      compiler = create_compiler(options)

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
          raise Puppet::Error, "No input to process given on command line or stdin"
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
      raise Puppet::Error, "error while rendering epp" unless status
      buffer.string
    end
  end

  def dump_parse(source, filename, options, show_filename = true)
    output = ""
    dumper = Puppet::Pops::Model::ModelTreeDumper.new
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
      output << dumper.dump(parse_result) << "\n"
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
          Puppet.err("Only .yaml or .pp can be used as a --values_file")
        end
      rescue => e
        Puppet.err("Could not load --values_file #{e.message}")
      end
      if !(template_values.nil? || template_values.is_a?(Hash))
        Puppet.err("--values_file option must evaluate to a Hash or undef/nil, got: '#{template_values.class}'")
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
        Puppet.err("--values option must evaluate to a Hash or undef, got: '#{result.class}'")
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
    fact_values = options[:facts] ? YAML.load_file(options[:facts]) : {}
    node = Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", fact_values))
    compiler = Puppet::Parser::Compiler.new(node)
    # configure compiler with facts and node related data
    # Set all global variables from facts
    fact_values.each {|param, value| compiler.topscope[param] = value }
    # Configured trusted data (even if there are none)
    compiler.topscope.set_trusted(node.trusted_data)
    # Set the facts hash
    compiler.topscope.set_facts(fact_values)

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
