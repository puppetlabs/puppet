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
            notice(Error == Error[default])
            notice(Error == Error[default, default])
            notice(Error['puppet/error'] == Error['puppet/error', default])
            notice(Error['puppet/error', 'ouch'] == Error['puppet/error', 'ouch'])
            notice(Error['puppet/error', 'ouch'] != Error['puppet/error', 'ouch!'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true true true true))
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

    context 'a Error instance' do
      it 'can be created from a string' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error')
            notice($o)
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "Error({'message' => 'bad tings happened', 'kind' => 'puppet/error', 'issue_code' => 'ERROR'})",
          "Error['puppet/error', 'ERROR']"
        ])
      end

      it 'can be created from a hash' do
        code = <<-CODE
            $o = Error(message => 'Sorry, not implemented', kind => 'puppet/error', issue_code => 'NOT_IMPLEMENTED')
            notice($o)
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq([
          "Error({'message' => 'Sorry, not implemented', 'kind' => 'puppet/error', 'issue_code' => 'NOT_IMPLEMENTED'})",
          "Error['puppet/error', 'NOT_IMPLEMENTED']"
        ])
      end

      it 'is an instance of its type' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error')
            notice($o =~ type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching kind' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error')
            notice($o =~ Error[/puppet\\/error/])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching default issue' do
        code = <<-CODE
            $o = Error('bad tings happened')
            notice($o =~ Error[default, 'ERROR'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching issue' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error', 'FEE')
            notice($o =~ Error[default, Enum['FOO', 'FEE', 'FUM']])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is an instance of matching kind and issue' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error', 'FEE')
            notice($o =~ Error['puppet/error', Enum['FOO', 'FEE', 'FUM']])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['true'])
      end

      it 'is not an instance unless kind matches' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppetlabs/error')
            notice($o =~ Error[/puppet\\/error/])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'is not an instance if default issue is not matched' do
        code = <<-CODE
            $o = Error('bad tings happened', undef)
            notice($o =~ Error[default, 'OTHER'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'is not an instance of non matching issue' do
        code = <<-CODE
            $o = Error('bad tings happened', nil, 'BAR')
            notice($o =~ Error[default, Enum['FOO', 'FEE', 'FUM']])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false'])
      end

      it 'is not an instance unless both kind and issue is a match' do
        code = <<-CODE
            $o = Error('bad tings happened', 'puppet/error', 'FEE')
            notice($o =~ Error['puppetlabs/error', Enum['FOO', 'FEE', 'FUM']])
            notice($o =~ Error['puppet/error', Enum['FOO', 'FUM']])
        CODE
        expect(eval_and_collect_notices(code)).to eq(['false', 'false'])
      end
    end
  end
end
end
end
