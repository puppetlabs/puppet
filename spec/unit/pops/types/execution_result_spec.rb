require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'ExecutionResult' do
  before(:each) { Puppet[:tasks] = true }

  context 'when used in Puppet expressions' do
    include PuppetSpec::Compiler
    it 'is equal to itself only' do
      expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true false false))
          $t = ExecutionResult
          notice(ExecutionResult =~ Type[ExecutionResult])
          notice(ExecutionResult == ExecutionResult)
          notice(ExecutionResult < ExecutionResult)
          notice(ExecutionResult > ExecutionResult)
      CODE
    end

    context 'a ExecutionResult instance' do
      it 'can be created from an empty hash' do
        code = <<-CODE
            $o = ExecutionResult({})
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "ExecutionResult({})",
        ])
      end

      it 'can be created with a value' do
        code = <<-CODE
            $o = ExecutionResult('example.com' => {value => 'hello'})
            notice($o)
            notice($o.empty)
            notice($o.ok)
            notice($o.count)
            notice($o.value('example.com'))
            notice($o.values)
            notice($o.ok_nodes)
            notice($o.error_nodes)
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "ExecutionResult({'example.com' => 'hello'})",
          'false',
          'true',
          '1',
          'hello',
          '[hello]',
          "ExecutionResult({'example.com' => 'hello'})",
          "ExecutionResult({})",
        ])
      end

      it 'can be created with an error' do
        code = <<-CODE
            $o = ExecutionResult('example.com' => {error => { 'msg' => 'nope', 'issue_code' => 'BAD'}})
            notice($o)
            notice($o.empty)
            notice($o.ok)
            notice($o.count)
            notice($o.value('example.com'))
            notice($o.values)
            notice($o.ok_nodes)
            notice($o.error_nodes)
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "ExecutionResult({'example.com' => Error({'message' => 'nope', 'issue_code' => 'BAD'})})",
          'false',
          'false',
          '1',
          "Error({'message' => 'nope', 'issue_code' => 'BAD'})",
          "[Error({'message' => 'nope', 'issue_code' => 'BAD'})]",
          'ExecutionResult({})',
          "ExecutionResult({'example.com' => Error({'message' => 'nope', 'issue_code' => 'BAD'})})"
        ])
      end

      it 'can be created with an error and a partial result' do
        code = <<-CODE
            $o = ExecutionResult('example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'})
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "ExecutionResult({'example.com' => Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'})})"
        ])
      end

      it 'can be created with an errors and ok values' do
        code = <<-CODE
            $o = ExecutionResult(
              'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
              'beta.example.com' => {value => 'total success'})
            notice($o)
            notice($o.empty)
            notice($o.ok)
            notice($o.count)
            notice($o['alpha.example.com'])
            notice($o['beta.example.com'])
            notice($o.values)
            notice($o.ok_nodes)
            notice($o.error_nodes)
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "ExecutionResult({'alpha.example.com' => Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'}), 'beta.example.com' => 'total success'})",
          'false',
          'false',
          '2',
          "Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'})",
          'total success',
          "[Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'}), total success]",
          "ExecutionResult({'beta.example.com' => 'total success'})",
          "ExecutionResult({'alpha.example.com' => Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'})})"
        ])
      end

      context 'using iterative features' do
        context 'using a 1 argument block' do
          it 'can do #all' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {error => { 'msg' => 'bad'}})
                notice($o.all |$e| { $e[1] =~ Error })
            CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'can do #any' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {error => { 'msg' => 'bad'}})
                notice($o.any |$e| { $e[1] !~ Error })
            CODE
            expect(eval_and_collect_notices(code)).to eq(['false'])
          end

          it 'can do #each' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {value => 'total success'})
                $o.each |$e| { notice("Node ${e[0]} returned ${e[1]}") }
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Node alpha.example.com returned Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'})",
              'Node beta.example.com returned total success'
            ])
          end

          it 'can do #filter' do
            code = <<-CODE
              $o = ExecutionResult(
                'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                'beta.example.com' => {value => 'total success'})
              $o.filter |$e| { $e[0] =~ /^beta/ }.each |$e| { notice($e[1]) }
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              'total success'
            ])
          end

          it 'can do #map' do
            code = <<-CODE
              $o = ExecutionResult(
                'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                'beta.example.com' => {value => 'total success'})
              notice($o.map |$e| { $e[1] })
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              "[Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'}), total success]"
            ])
          end
        end

        context 'using a 2 argument block' do
          it 'can do #all' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {error => { 'msg' => 'bad'}})
                notice($o.all |$k, $v| { $v =~ Error })
            CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'can do #any' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {error => { 'msg' => 'bad'}})
                notice($o.any |$k, $v| { $v !~ Error })
            CODE
            expect(eval_and_collect_notices(code)).to eq(['false'])
          end

          it 'can do #each' do
            code = <<-CODE
                $o = ExecutionResult(
                  'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                  'beta.example.com' => {value => 'total success'})
                $o.each |$k, $v| { notice("Node $k returned $v") }
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Node alpha.example.com returned Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'})",
              'Node beta.example.com returned total success'
            ])
          end

          it 'can do #filter' do
            code = <<-CODE
              $o = ExecutionResult(
                'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                'beta.example.com' => {value => 'total success'})
              $o.filter |$k, $v| { $k =~ /^beta/ }.each |$k, $v| { notice($v) }
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              'total success'
            ])
          end

          it 'can do #map' do
            code = <<-CODE
              $o = ExecutionResult(
                'alpha.example.com' => {error => { 'msg' => 'nope'}, value => 'almost there, almost th...argh'},
                'beta.example.com' => {value => 'total success'})
              notice($o.map |$k, $v| { $v })
            CODE
            expect(eval_and_collect_notices(code)).to eq([
              "[Error({'message' => 'nope', 'partial_result' => 'almost there, almost th...argh'}), total success]"
            ])
          end
        end
      end
    end
  end
end
end
end
