require 'puppet'
require 'puppet/pops'
require 'puppet/pops/evaluator/json_strict_literal_evaluator'

class Puppet::InfoService::ClassInformationService

  def initialize
    @file_to_result = {}
    @parser = Puppet::Pops::Parser::EvaluatingParser.new()
  end

  def classes_per_environment(env_file_hash)
    # In this version of puppet there is only one way to parse manifests, as feature switches per environment
    # are added or removed, this logic needs to change to compute the result per environment with the correct
    # feature flags in effect.

    unless env_file_hash.is_a?(Hash)
      raise ArgumentError, 'Given argument must be a Hash'
    end

    result = {}

    # for each environment
    #   for each file
    #     if file already processed, use last result or error
    #
    env_file_hash.each do |env, files|
      env_result = result[env] = {}
      files.each do |f|
        env_result[f] = result_of(f)
      end
    end
    result
  end

  private

  def type_parser
    # Safe to cache this as it would otherwise constantly build up the visitor cache
    @@type_parser ||= Puppet::Pops::Types::TypeParser.new
  end

  def literal_evaluator
    @@literal_evaluator ||= Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator.new
  end

  def result_of(f)
    entry =  @file_to_result[f]
    if entry.nil?
      @file_to_result[f] = entry = parse_file(f)
    end
    entry
  end

  def parse_file(f)
    return {:error => "The file #{f} does not exist"} unless Puppet::FileSystem.exist?(f)

    begin
      parse_result = @parser.parse_file(f)
      {:classes =>
        parse_result.definitions.select {|d| d.is_a?(Puppet::Pops::Model::HostClassDefinition)}.map do |d|
          {:name   => d.name,
           :params => params = d.parameters.map {|p| extract_param(p) }
          }
        end
      }
    rescue StandardError => e
      {:error => e.message }
    end
  end

  def extract_param(p)
    extract_default(extract_type({:name => p.name}, p), p)
  end

  def extract_type(structure, p)
    return structure if p.type_expr.nil?
    structure[:type] = typeexpr_to_string(p.type_expr)
    structure
  end

  def extract_default(structure, p)
    value_expr = p.value
    return structure if value_expr.nil?
    default_value = value_as_literal(value_expr)
    structure[:default_literal] = default_value unless default_value.nil?
    structure[:default_source] = extract_value_source(value_expr)
    structure
  end

  def typeexpr_to_string(type_expr)
    begin
      type_parser.interpret_any(type_expr, nil).to_s
    rescue Puppet::ParseError
      # type is to complex - contains expressions that are not literal
      nil
    end
  end

  def value_as_literal(value_expr)
    catch(:not_literal) do
      return literal_evaluator.literal(value_expr)
    end
    nil
  end

  # Extracts the source for the expression
  def extract_value_source(value_expr)
    position = Puppet::Pops::Adapters::SourcePosAdapter.adapt(value_expr)
    position.extract_tree_text
  end
end