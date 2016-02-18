require 'puppet/face'
require 'puppet/parser'

Puppet::Face.define(:parser, '0.0.1') do
  copyright "Puppet Labs", 2014
  license   "Apache 2 license; see COPYING"

  summary "Interact directly with the parser."

  action :validate do
    summary "Validate the syntax of one or more Puppet manifests."
    arguments "[<manifest>] [<manifest> ...]"
    returns "Nothing, or the first syntax error encountered."
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
          Puppet.notice "No manifest specified. Validating the default manifest #{manifest}"
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
        raise Puppet::Error, "One or more file(s) specified did not exist:\n#{missing_files.collect {|f| " " * 3 + f + "\n"}}"
      end
      nil
    end
  end


  action (:dump) do
    summary "Outputs a dump of the internal parse tree for debugging"
    arguments "-e <source>| [<manifest> ...] "
    returns "A dump of the resulting AST model unless there are syntax or validation errors."
    description <<-'EOT'
      This action parses and validates the Puppet DSL syntax without compiling a catalog
      or syncing any resources.

      The command accepts one or more manifests (.pp) files, or an -e followed by the puppet
      source text.
      If no arguments are given, the stdin is read (unless it is attached to a terminal)

      The output format of the dumped tree is intended for debugging purposes and is
      not API, it may change from time to time.
    EOT

    option "--e <source>" do
      default_to { nil }
      summary "dump one source expression given on the command line."
    end

    option("--[no-]validate") do
      summary "Whether or not to validate the parsed result, if no-validate only syntax errors are reported"
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
          raise Puppet::Error, "No input to parse given on command line or stdin"
        end
      else
        missing_files = []
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
          dumps + "One or more file(s) specified did not exist:\n" + missing_files.collect { |f| "   #{f}" }.join("\n")
        end
      end
    end
  end

  def dump_parse(source, filename, options, show_filename = true)
    output = ""
    dumper = Puppet::Pops::Model::ModelTreeDumper.new
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
      output << dumper.dump(parse_result) << "\n"
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
    Puppet.override( {:loaders => loaders } , 'For puppet parser validate') do
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
