require 'spec_helper'
require 'puppet_spec/language'

module PuppetSpec
module FunctionRunner
  extend RSpec::Matchers::DSL

  def self.collect_log(decl, call)
    Puppet[:code] = decl
    compiler = Puppet::Parser::Compiler.new(Puppet::Node.new('specification'))
    evaluator = Puppet::Pops::Parser::EvaluatingParser.new()
    logs = []
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      compiler.compile
      evaluator.evaluate_string(compiler.topscope, call)
    end
    logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
    logs
  end

  def run_expectations(decl, expectations)
    expectations.each do |call, result|
      if result.is_a?(Regexp)
        it "'#{decl}' called with '#{call}' should fail with error #{result}" do
          expect {FunctionRunner.collect_log(decl, call)}.to raise_error(Puppet::Error, result)
        end
      else
        it "'#{decl}' called with '#{call}' should produce #{result}" do
          expect(FunctionRunner.collect_log(decl, call)).to include(*result)
        end
      end
    end
  end
end

describe "Function parameter default expressions" do
  extend FunctionRunner

  context "to the left of a parameter can use that parameter's value" do
    run_expectations('function example($a = 10, $b = $a) { notice("\$a == ${a}") notice("\$b == ${b}") }',
      { 'example()' => ['$a == 10', '$b == 10'],
        'example(2)' => ['$a == 2', '$b == 2'],
        'example(2,5)' => ['$a == 2', '$b == 5'] })

    run_expectations('function example($a, $b = $a) { notice("\$a == ${a}") notice("\$b == ${b}") }',
      { 'example(10)' => ['$a == 10', '$b == 10'],
        'example(10,20)' => ['$a == 10', '$b == 20'] })
  end

  context 'that references a variable to the right' do
    run_expectations('function example($a = 10, $b = $c, $c = 20) { notice("\$a == ${a}") notice("\$b == ${b}") notice("\$c == ${c}") }',
      { 'example(1)' => /\$b tries to access unevaluated \$c/,
        'example(1,2)' => ['$a == 1', '$b == 2', '$c == 20'],
        'example(1,2,3)' => ['$a == 1', '$b == 2', '$c == 3'] })
  end

  context 'uses a separate nested match scope for each parameter' do
    run_expectations('function example($a = $0, $b = $1) { notice("\$a == ${a}") notice("\$b == ${b}") }',
      { 'example()' => ['$a == ', '$b == '] })

    run_expectations("function example($a = ['hello' =~ /(h)(.*)/, $1, $2], $b = $1) { notice(\"\\$a == ${a}\") notice(\"\\$b == ${b}\") }",
      { 'example()' => ['$a == [true, h, ello]', '$b == '] })

    run_expectations("function example($a = ['hello' =~ /(h)(.*)/, $1, $2], $b = ['hi' =~ /(h)(.*)/, $1, $2], $c = $1) { notice(\"\\$a == ${a}\") notice(\"\\$b == ${b}\")  notice(\"\\$c == ${c}\")}",
      { 'example()' => ['$a == [true, h, ello]', '$b == [true, h, i]', '$c == '] })

    run_expectations("function example($a = ['hi' =~ /(h)(.*)/, $1, if'foo' =~ /f(oo)/ { $1 }, $1, $2], $b = $0) { notice(\"\\$a == ${a}\") notice(\"\\$b == ${b}\")}",
      { 'example()' => ['$a == [true, h, oo, h, i]', '$b == '] })
  end

  context 'can not see match scope from calling scope' do
    run_expectations("function example($a = $0) { notice(\"\\$a == ${a}\")}\nfunction caller() { example() }",
      { "$tmp = 'foo' =~ /(f)(o)(o)/\ncaller()" => ['$a == '] })
  end

  context 'can access earlier match results when produced using the match function' do
    run_expectations("function example($a = 'hello'.match(/(h)(.*)/), $b = $a[0],  $c = $a[1]) { notice(\"\\$a == ${a}\") notice(\"\\$b == ${b}\")  notice(\"\\$c == ${c}\")}",
      { 'example()' => ['$a == [hello, h, ello]', '$b == hello', '$c == h'] })
  end

  context 'will not permit assignments' do
    run_expectations('function example($a = $x = $0) { notice("\$a == ${a}")}',
      { 'example()' => /Syntax error at '='/ })

    run_expectations('function example($a = [$x = 3]) { notice("\$a == ${a}")}',
      { 'example()' => /Assignment not allowed here/ })
  end
end
end
