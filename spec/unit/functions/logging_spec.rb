require 'spec_helper'
require 'puppet_spec/compiler'

describe 'the log function' do
  include PuppetSpec::Compiler

  def collect_logs(code)
    Puppet[:code] = code
    node = Puppet::Node.new('logtest')
    compiler = Puppet::Parser::Compiler.new(node)
    node.environment.check_for_reparse
    logs = []
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      compiler.compile
    end
    logs
  end

  def expect_log(code, log_level, message)
    logs = collect_logs(code)
    expect(logs.size).to eql(1)
    expect(logs[0].level).to eql(log_level)
    expect(logs[0].message).to eql(message)
  end

  before(:each) do
    Puppet[:log_level] = 'debug'
  end

  Puppet::Util::Log.levels.each do |level|
    context "for log level '#{level}'" do
      it 'can be called' do
        expect_log("#{level.to_s}('yay')", level, 'yay')
      end

      it 'joins multiple arguments using space' do
        # Not using the evaluator would result in yay {"a"=>"b", "c"=>"d"}
        expect_log("#{level.to_s}('a', 'b', 3)", level, 'a b 3')
      end

      it 'uses the evaluator to format output' do
        # Not using the evaluator would result in yay {"a"=>"b", "c"=>"d"}
        expect_log("#{level.to_s}('yay', {a => b, c => d})", level, 'yay {a => b, c => d}')
      end

      it 'returns undef value' do
        logs = collect_logs("notice(type(#{level.to_s}('yay')))")
        expect(logs.size).to eql(2)
        expect(logs[1].level).to eql(:notice)
        expect(logs[1].message).to eql('Undef')
      end
    end
  end
end
