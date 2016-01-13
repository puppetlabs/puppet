require 'spec_helper'
require 'puppet_spec/language'

module PuppetSpec
module EppRunner
  extend RSpec::Matchers::DSL

  def self.collect_log(source, args, code)
    Puppet[:code] = code
    compiler = Puppet::Parser::Compiler.new(Puppet::Node.new('specification'))
    logs = []
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      compiler.compile
      Puppet::Pops::Evaluator::EppEvaluator.inline_epp(compiler.topscope, source, args)
    end
    logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
    logs
  end

  def run_expectations(decl, expectations, code = 'undef')
    expectations.each do |args, result|
      if result[0].is_a?(Class)
        it "'#{decl}' called with #{args} should fail with error #{result}" do
          expect {EppRunner.collect_log(decl, args, code)}.to raise_error(result[0], result[1])
        end
      else
        it "'#{decl}' called with #{args} should produce #{result}" do
          expect(EppRunner.collect_log(decl, args, code)).to include(*result)
        end
      end
    end
  end
end

describe "EPP parameter default expressions" do
  extend EppRunner

  context "to the left of a parameter can use that parameter's value" do
    run_expectations('<%| $a = 10, $b = $a |%><%= notice($a) %><%= notice($b) %>',
      [ [{}, ['10', '10']],
        [{'a' => 2}, ['2', '2']],
        [{'a' => 2, 'b' => 5}, ['2', '5'] ]])

    run_expectations('<%| $a, $b = $a |%><%= notice($a) %><%= notice($b) %>',
      [ [ {'a' => 10}, ['10', '10']],
        [ {'a' => 10, 'b' => 20}, ['10', '20']]])
  end

  context 'that references a variable to the right' do
    run_expectations('<%| $a = 10, $b = $c, $c = 20 |%><%= notice($a) %><%= notice($b) %><%= notice($c) %>',
      [ [ {'a' => 1}, [Puppet::Error, /\$b tries to access unevaluated \$c/]],
        [ {'a' => 1, 'b' => 2}, ['1', '2', '20']],
        [ {'a' => 1, 'b' => 2, 'c' => 3}, ['1', '2', '3']]])
  end

  context 'uses a separate nested match scope for each parameter' do
    run_expectations('<%| $a = $0, $b = $1 |%><%= notice($a) %><%= notice($b) %>',
      [ [{}, ['', '']] ])

    run_expectations("<%| $a = ['hello' =~ /(h)(.*)/, $1, $2], $b = $1 |%><%= notice($a) %><%= notice($b) %>",
      [ [{}, ['[true, h, ello]', '']] ])

    run_expectations("<%| $a = ['hello' =~ /(h)(.*)/, $1, $2], $b = ['hi' =~ /(h)(.*)/, $1, $2], $c = $1 |%><%= notice($a) %><%= notice($b) %><%= notice($c) %>",
      [ [{}, ['[true, h, ello]', '[true, h, i]', '']] ])

    run_expectations("<%| $a = ['hi' =~ /(h)(.*)/, $1, if'foo' =~ /f(oo)/ { $1 }, $1, $2], $b = $0 |%><%= notice($a) %><%= notice($b) %>",
      [ [{}, ['[true, h, oo, h, i]', '']] ])
  end

  context 'can not see match scope from calling scope' do
    run_expectations('<%| $a = $tmp, $b = $0 |%><%= called_from_template($a, $b) %>',
      [ [{}, ['$ax == true', '$bx == ']] ], "function called_from_template($ax, $bx) { notice(\"\\$ax == $ax\") notice(\"\\$bx == $bx\") }\n$tmp = 'foo' =~ /(f)(o)(o)/\n")
  end

  context 'can access earlier match results when produced using the match function' do
    run_expectations("<%| $a = 'hello'.match(/(h)(.*)/), $b = $a[0],  $c = $a[1] |%><%= notice($a) %><%= notice($b) %><%= notice($c) %>",
      [ [{}, ['[hello, h, ello]', 'hello', 'h']] ])
  end

  context 'will not permit assignments' do
    run_expectations('<%| $a = $x = $0 |%><%= notice($a) %>',
      [ [{}, [ArgumentError, /Syntax error at '='/]] ])

    run_expectations('<%| $a = [$x = 3] |%><%= notice($a) %>',
      [ [{}, [ArgumentError, /Assignment not allowed here/]] ])
  end
end
end
