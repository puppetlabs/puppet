require 'puppet/face'
require 'puppet/parser'

Puppet::Face.define(:parser, '0.0.1') do
  copyright "Puppet Inc.", 2014
  license   _("Apache 2 license; see COPYING")

  summary _("Interact directly with the parser.")

  action :validate do
    summary _("Validate the syntax of one or more Puppet manifests.")
    arguments _("[<manifest>] [<manifest> ...]")
    returns _("Nothing, or the first syntax error encountered.")
    description <<-'EOT'
      This action validates Puppet DSL syntax without compiling a catalog or
      syncing any resources. If no manifest files are provided, it will
      validate the default site manifest.

      When validating multiple issues per file are reported up
      to the settings of max_error, and max_warnings. The processing stops
      after having reported issues for the first encountered file with errors.
    EOT
    examples <<-'EOT'
      Validate the default site manifest at /etc/puppetlabs/puppet/manifests/site.pp:

      $ puppet parser validate

      Validate two arbitrary manifest files:

      $ puppet parser validate init.pp vhost.pp

      Validate from STDIN:

      $ cat init.pp | puppet parser validate
    EOT
    when_invoked do |*args|
      args.pop
      files = args
      if files.empty?
        if not STDIN.tty?
          Puppet[:code] = STDIN.read
          validate_manifest
        else
          manifest = Puppet.lookup(:current_environment).manifest
          files << manifest
          Puppet.notice _("No manifest specified. Validating the default manifest %{manifest}") % { manifest: manifest }
        end
      end
      missing_files = []
      files.each do |file|
        if Puppet::FileSystem.exist?(file)
          validate_manifest(file)
        else
          missing_files << file
        end
      end
      unless missing_files.empty?
        raise Puppet::Error, _("One or more file(s) specified did not exist:\n%{files}") % { files: missing_files.collect {|f| " " * 3 + f + "\n"} }
      end
      nil
    end
  end


  action (:dump) do
    summary _("Outputs a dump of the internal parse tree for debugging")
    arguments "[--format <old|pn|json>] [--pretty] { -e <source> | [<templates> ...] } "
    returns _("A dump of the resulting AST model unless there are syntax or validation errors.")
    description <<-'EOT'
      This action parses and validates the Puppet DSL syntax without compiling a catalog
      or syncing any resources.

      The output format can be controlled using the --format <old|pn|json> where:
      * 'old' is the default, but now deprecated format which is not API.
      * 'pn' is the Puppet Extended S-Expression Notation.
      * 'json' outputs the same graph as 'pn' but with JSON syntax.

      The output will be "pretty printed" when the option --pretty is given together with --format 'pn' or 'json'. 
      This option has no effect on the 'old' format.

      The command accepts one or more manifests (.pp) files, or an -e followed by the puppet
      source text.
      If no arguments are given, the stdin is read (unless it is attached to a terminal)

      The output format of the dumped tree is intended for debugging purposes and is
      not API, it may change from time to time.
    EOT

    option "--e " + _("<source>") do
      default_to { nil }
      summary _("dump one source expression given on the command line.")
    end

    option("--[no-]validate") do
      summary _("Whether or not to validate the parsed result, if no-validate only syntax errors are reported")
    end

    option('--format ' + _('<old, pn, or json>')) do
      summary _("Get result in 'old' (deprecated format), 'pn' (new format), or 'json' (new format in JSON).")
    end

    option('--pretty') do
      summary _('Pretty print output. Only applicable together with --format pn or json')
    end

    when_invoked do |*args|
      require 'puppet/pops'
      options = args.pop
      if options[:e]
        dump_parse(options[:e], 'command-line-string', options, false)
      elsif args.empty?
        if ! STDIN.tty?
          dump_parse(STDIN.read, 'stdin', options, false)
        else
          raise Puppet::Error, _("No input to parse given on command line or stdin")
        end
      else
        files = args
        available_files = files.select do |file|
          Puppet::FileSystem.exist?(file)
        end
        missing_files = files - available_files

        dumps = available_files.collect do |file|
          dump_parse(Puppet::FileSystem.read(file, :encoding => 'utf-8'), file, options)
        end.join("")

        if missing_files.empty?
          dumps
        else
          dumps + _("One or more file(s) specified did not exist:\n") + missing_files.collect { |f| "   #{f}" }.join("\n")
        end
      end
    end
  end

  def dump_parse(source, filename, options, show_filename = true)
    output = ""
    evaluating_parser = Puppet::Pops::Parser::EvaluatingParser.new
    begin
      if options[:validate]
        parse_result = evaluating_parser.parse_string(source, filename)
      else
        # side step the assert_and_report step
        parse_result = evaluating_parser.parser.parse_string(source)
      end
      if show_filename
        output << "--- #{filename}"
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

  # @api private
  def validate_manifest(manifest = nil)
    env = Puppet.lookup(:current_environment)
    loaders = Puppet::Pops::Loaders.new(env)
    Puppet.override( {:loaders => loaders } , _('For puppet parser validate')) do
      begin
        validation_environment = manifest ? env.override_with(:manifest => manifest) : env
        validation_environment.check_for_reparse
        validation_environment.known_resource_types.clear
      rescue => detail
        Puppet.log_exception(detail)
        exit(1)
      end
    end
  end
end
