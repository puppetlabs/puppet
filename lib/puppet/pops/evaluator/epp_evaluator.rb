# Handler of Epp call/evaluation from the epp and inline_epp functions
#
class Puppet::Pops::Evaluator::EppEvaluator

  def self.inline_epp(scope, epp_source, template_args = nil)
    unless epp_source.is_a?(String)
      #TRANSLATORS 'inline_epp()' is a method name and 'epp' refers to 'Embedded Puppet (EPP) template' and should not be translated
      raise ArgumentError, _("inline_epp(): the first argument must be a String with the epp source text, got a %{class_name}") %
          { class_name: epp_source.class }
    end

    # Parse and validate the source
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new
    begin
      result = parser.parse_string(epp_source, 'inlined-epp-text')
    rescue Puppet::ParseError => e
      #TRANSLATORS 'inline_epp()' is a method name and 'EPP' refers to 'Embedded Puppet (EPP) template' and should not be translated
      raise ArgumentError, _("inline_epp(): Invalid EPP: %{detail}") % { detail: e.message }
    end

    # Evaluate (and check template_args)
    evaluate(parser, 'inline_epp', scope, false, result, template_args)
  end

  def self.epp(scope, file, env_name, template_args = nil)
    unless file.is_a?(String)
      #TRANSLATORS 'epp()' is a method name and should not be translated
      raise ArgumentError, _("epp(): the first argument must be a String with the filename, got a %{class_name}") % { class_name: file.class }
    end

    unless Puppet::FileSystem.exist?(file)
      unless file =~ /\.epp$/
        file = file + ".epp"
      end
    end

    scope.debug "Retrieving epp template #{file}"
    template_file = Puppet::Parser::Files.find_template(file, env_name)
    if template_file.nil? ||  !Puppet::FileSystem.exist?(template_file)
      raise Puppet::ParseError, _("Could not find template '%{file}'") % { file: file }
    end

    # Parse and validate the source
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new
    begin
      result = parser.parse_file(template_file)
    rescue Puppet::ParseError => e
      #TRANSLATORS 'epp()' is a method name and 'EPP' refers to 'Embedded Puppet (EPP) template' and should not be translated
      raise ArgumentError, _("epp(): Invalid EPP: %{detail}") % { detail: e.message }
    end

    # Evaluate (and check template_args)
    evaluate(parser, 'epp', scope, true, result, template_args)
  end

  def self.evaluate(parser, func_name, scope, use_global_scope_only, parse_result, template_args)
    template_args, template_args_set = handle_template_args(func_name, template_args)

    body = parse_result.body
    unless body.is_a?(Puppet::Pops::Model::LambdaExpression)
      #TRANSLATORS 'LambdaExpression' is a class name and should not be translated
      raise ArgumentError, _("%{function_name}(): the parser did not produce a LambdaExpression, got '%{class_name}'") %
          { function_name: func_name, class_name: body.class }
    end
    unless body.body.is_a?(Puppet::Pops::Model::EppExpression)
      #TRANSLATORS 'EppExpression' is a class name and should not be translated
      raise ArgumentError, _("%{function_name}(): the parser did not produce an EppExpression, got '%{class_name}'") %
          { function_name: func_name, class_name: body.body.class }
    end
    unless parse_result.definitions.empty?
      #TRANSLATORS 'EPP' refers to 'Embedded Puppet (EPP) template'
      raise ArgumentError, _("%{function_name}(): The EPP template contains illegal expressions (definitions)") %
          { function_name: func_name }
    end

    parameters_specified = body.body.parameters_specified
    if parameters_specified || template_args_set
      enforce_parameters = parameters_specified
    else
      enforce_parameters = true
    end

    # filter out all qualified names and set them in qualified_variables
    # only pass unqualified (filtered) variable names to the the template
    filtered_args = {}
    template_args.each_pair do |k, v|
      if k =~ /::/
        k = k[2..-1] if k.start_with?('::')
        scope[k] = v
      else
        filtered_args[k] = v
      end
    end
    template_args = filtered_args

    # inline_epp() logic sees all local variables, epp() all global
    if use_global_scope_only
      scope.with_global_scope do |global_scope|
        parser.closure(body, global_scope).call_by_name(template_args, enforce_parameters)
      end
    else
      parser.closure(body, scope).call_by_name(template_args, enforce_parameters)
    end
  end
  private_class_method :evaluate

  def self.handle_template_args(func_name, template_args)
    if template_args.nil?
      [{}, false]
    else
      unless template_args.is_a?(Hash)
        #TRANSLATORS 'template_args' is a variable name and should not be translated
        raise ArgumentError, _("%{function_name}(): the template_args must be a Hash, got a %{class_name}") %
            { function_name: func_name, class_name: template_args.class }
      end
      [template_args, true]
    end
  end
  private_class_method :handle_template_args
end
