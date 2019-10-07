require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
  module Types
    describe 'Error type' do
      context 'when used in Puppet expressions' do
        include PuppetSpec::Compiler
        it 'is equal to itself only' do
          expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true false false))
            $t = Error
            notice(Error =~ Type[Error])
            notice(Error == Error)
            notice(Error < Error)
            notice(Error > Error)
            CODE
        end

        context "when parameterized" do
          it 'is equal other types with the same parameterization' do
            code = <<-CODE
              notice(Error['puppet/error'] == Error['puppet/error', default])
              notice(Error['puppet/error', 'ouch'] == Error['puppet/error', 'ouch'])
              notice(Error['puppet/error', 'ouch'] != Error['puppet/error', 'ouch!'])
              CODE
            expect(eval_and_collect_notices(code)).to eq(%w(true true true))
          end

          it 'is assignable from more qualified types' do
            expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true true))
              notice(Error > Error['puppet/error'])
              notice(Error['puppet/error'] > Error['puppet/error', 'ouch'])
              notice(Error['puppet/error', default] > Error['puppet/error', 'ouch'])
              CODE
          end

          it 'is not assignable unless kind is assignable' do
            expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true false true false true false true))
              notice(Error[/a/] > Error['hah'])
              notice(Error[/a/] > Error['hbh'])
              notice(Error[Enum[a,b,c]] > Error[a])
              notice(Error[Enum[a,b,c]] > Error[d])
              notice(Error[Pattern[/a/, /b/]] > Error[a])
              notice(Error[Pattern[/a/, /b/]] > Error[c])
              notice(Error[Pattern[/a/, /b/]] > Error[Enum[a, b]])
              CODE
          end

          it 'presents parsable string form' do
            code = <<-CODE
              notice(Error['a'])
              notice(Error[/a/])
              notice(Error[Enum['a', 'b']])
              notice(Error[Pattern[/a/, /b/]])
              notice(Error['a', default])
              notice(Error[/a/, default])
              notice(Error[Enum['a', 'b'], default])
              notice(Error[Pattern[/a/, /b/], default])
              notice(Error[default,'a'])
              notice(Error[default,/a/])
              notice(Error[default,Enum['a', 'b']])
              notice(Error[default,Pattern[/a/, /b/]])
              notice(Error['a','a'])
              notice(Error[/a/,/a/])
              notice(Error[Enum['a', 'b'],Enum['a', 'b']])
              notice(Error[Pattern[/a/, /b/],Pattern[/a/, /b/]])
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Error['a']",
              'Error[/a/]',
              "Error[Enum['a', 'b']]",
              "Error[Pattern[/a/, /b/]]",
              "Error['a']",
              'Error[/a/]',
              "Error[Enum['a', 'b']]",
              "Error[Pattern[/a/, /b/]]",
              "Error[default, 'a']",
              'Error[default, /a/]',
              "Error[default, Enum['a', 'b']]",
              "Error[default, Pattern[/a/, /b/]]",
              "Error['a', 'a']",
              'Error[/a/, /a/]',
              "Error[Enum['a', 'b'], Enum['a', 'b']]",
              "Error[Pattern[/a/, /b/], Pattern[/a/, /b/]]",
            ])
          end
        end

        context 'an Error instance' do
          it 'can be created using positional arguments' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error', {'detail' => 'val'}, 'OOPS')
              notice($o)
              notice(type($o))
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Error({'msg' => 'bad things happened', 'kind' => 'puppet/error', 'details' => {'detail' => 'val'}, 'issue_code' => 'OOPS'})",
              "Error['puppet/error', 'OOPS']"
            ])
          end

          it 'can be created using named arguments' do
            code = <<-CODE
              $o = Error(msg => 'Sorry, not implemented', kind => 'puppet/error', issue_code => 'NOT_IMPLEMENTED')
              notice($o)
              notice(type($o))
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Error({'msg' => 'Sorry, not implemented', 'kind' => 'puppet/error', 'issue_code' => 'NOT_IMPLEMENTED'})",
              "Error['puppet/error', 'NOT_IMPLEMENTED']"
            ])
          end

          it 'exposes message' do
            code = <<-CODE
              $o = Error(msg => 'Sorry, not implemented', kind => 'puppet/error', issue_code => 'NOT_IMPLEMENTED')
              notice($o.message)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["Sorry, not implemented"])
          end

          it 'exposes kind' do
            code = <<-CODE
              $o = Error(msg => 'Sorry, not implemented', kind => 'puppet/error', issue_code => 'NOT_IMPLEMENTED')
              notice($o.kind)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["puppet/error"])
          end

          it 'exposes issue_code' do
            code = <<-CODE
              $o = Error(msg => 'Sorry, not implemented', kind => 'puppet/error', issue_code => 'NOT_IMPLEMENTED')
              notice($o.issue_code)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["NOT_IMPLEMENTED"])
          end

          it 'exposes details' do
            code = <<-CODE
              $o = Error(msg => 'Sorry, not implemented', kind => 'puppet/error', details => { 'detailk' => 'detailv' })
              notice($o.details)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["{detailk => detailv}"])
          end

          it 'is an instance of its inferred type' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error')
              notice($o =~ type($o))
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'is an instance of Error with matching kind' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error')
              notice($o =~ Error[/puppet\\/error/])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'is an instance of Error with matching issue_code' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error', {}, 'FEE')
              notice($o =~ Error[default, 'FEE'])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'is an instance of Error with matching kind and issue_code' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error', {}, 'FEE')
              notice($o =~ Error['puppet/error', 'FEE'])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'is not an instance of Error unless kind matches' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppetlabs/error')
              notice($o =~ Error[/puppet\\/error/])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['false'])
          end

          it 'is not an instance of Error unless issue_code matches' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppetlabs/error', {}, 'BAR')
              notice($o =~ Error[default, 'FOO'])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['false'])
          end

          it 'is not an instance of Error unless both kind and issue is a match' do
            code = <<-CODE
              $o = Error('bad things happened', 'puppet/error', {}, 'FEE')
              notice($o =~ Error['puppetlabs/error', 'FEE'])
              notice($o =~ Error['puppet/error', 'FUM'])
              CODE
            expect(eval_and_collect_notices(code)).to eq(['false', 'false'])
          end
        end
      end
    end
  end
end
