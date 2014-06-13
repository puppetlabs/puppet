# Handler of Epp call/evaluation from the epp and inline_epp functions
#
class Puppet::Pops::Evaluator::EppEvaluator

  def self.inline_epp(scope, epp_source, template_args = nil)
    unless epp_source.is_a?(String)
      raise ArgumentError, "inline_epp(): the first argument must be a String with the epp source text, got a #{epp_source.class}"
    end

    # Parse and validate the source
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new
    begin
      result = parser.parse_string(epp_source, 'inlined-epp-text')
    rescue Puppet::ParseError => e
      raise ArgumentError, "inline_epp(): Invalid EPP: #{e.message}"
    end

    # Evaluate (and check template_args)
    evaluate(parser, 'inline_epp', scope, false, result, template_args)
  end

  def self.epp(scope, file, env_name, template_args = nil)
    unless file.is_a?(String)
      raise ArgumentError, "epp(): the first argument must be a String with the filename, got a #{file.class}"
    end

    file = file + ".epp" unless file =~ /\.epp$/
    scope.debug "Retrieving epp template #{file}"
    template_file = Puppet::Parser::Files.find_template(file, env_name)
    unless template_file
      raise Puppet::ParseError, "Could not find template '#{file}'"
    end

    # Parse and validate the source
    parser = Puppet::Pops::Parser::EvaluatingParser::EvaluatingEppParser.new
    begin
      result = parser.parse_file(template_file)
    rescue Puppet::ParseError => e
      raise ArgumentError, "epp(): Invalid EPP: #{e.message}"
    end

    # Evaluate (and check template_args)
    evaluate(parser, 'epp', scope, true, result, template_args)
  end

  private

  def self.evaluate(parser, func_name, scope, use_global_scope_only, parse_result, template_args)
    template_args, template_args_set = handle_template_args(func_name, template_args)

    body = parse_result.body
    unless body.is_a?(Puppet::Pops::Model::LambdaExpression)
      raise ArgumentError, "#{func_name}(): the parser did not produce a LambdaExpression, got '#{body.class}'"
    end
    unless body.body.is_a?(Puppet::Pops::Model::EppExpression)
      raise ArgumentError, "#{func_name}(): the parser did not produce an EppExpression, got '#{body.body.class}'"
    end
    unless parse_result.definitions.empty?
      raise ArgumentError, "#{func_name}(): The EPP template contains illegal expressions (definitions)"
    end

    parameters_specified = body.body.parameters_specified
    if parameters_specified || template_args_set
      # no epp params or user provided arguments in a hash, epp() logic
      # only sees global + what was given
      closure_scope = scope.find_global_scope
      enforce_parameters = parameters_specified
    else
      # no epp params and no arguments were given => inline_epp() logic
      # sees all local variables, epp() all global
      closure_scope =  use_global_scope_only ? scope.find_global_scope : scope
      enforce_parameters = true
    end
    evaluated_result = parser.closure(body, closure_scope).call_by_name(scope, template_args, enforce_parameters)
    evaluated_result
  end

  def self.handle_template_args(func_name, template_args)
    if template_args.nil?
      [{}, false]
    else
      unless template_args.is_a?(Hash)
        raise ArgumentError, "#{func_name}(): the template_args must be a Hash, got a #{template_args.class}"
      end
      [template_args, true]
    end
  end
end
