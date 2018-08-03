require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
  module Types
    describe 'Deferred type' do
      context 'when used in Puppet expressions' do
        include PuppetSpec::Compiler
        it 'is equal to itself only' do
          expect(eval_and_collect_notices(<<-CODE)).to eq(%w(true true false false))
            $t = Deferred
            notice(Deferred =~ Type[Deferred])
            notice(Deferred == Deferred)
            notice(Deferred < Deferred)
            notice(Deferred > Deferred)
            CODE
        end

        context 'a Deferred instance' do
          it 'can be created using positional arguments' do
            code = <<-CODE
              $o = Deferred('michelangelo', [1,2,3])
              notice($o)
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Deferred({'name' => 'michelangelo', 'arguments' => [1, 2, 3]})"
            ])
          end

          it 'can be created using named arguments' do
            code = <<-CODE
              $o = Deferred(name =>'michelangelo', arguments => [1,2,3])
              notice($o)
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Deferred({'name' => 'michelangelo', 'arguments' => [1, 2, 3]})"
            ])
          end

          it 'is inferred to have the type Deferred' do
            pending 'bug in type() function outputs the entire pcore definition'
            code = <<-CODE
              $o = Deferred('michelangelo', [1,2,3])
              notice(type($o))
              CODE
            expect(eval_and_collect_notices(code)).to eq([
              "Deferred"
            ])
          end

          it 'exposes name' do
            code = <<-CODE
              $o = Deferred(name =>'michelangelo', arguments => [1,2,3])
              notice($o.name)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["michelangelo"])
          end

          it 'exposes arguments' do
            code = <<-CODE
              $o = Deferred(name =>'michelangelo', arguments => [1,2,3])
              notice($o.arguments)
              CODE
            expect(eval_and_collect_notices(code)).to eq(["[1, 2, 3]"])
          end

          it 'is an instance of its inferred type' do
            code = <<-CODE
              $o = Deferred(name =>'michelangelo', arguments => [1,2,3])
              notice($o =~ type($o))
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end

          it 'is an instance of Deferred' do
            code = <<-CODE
              $o = Deferred(name =>'michelangelo', arguments => [1,2,3])
              notice($o =~ Deferred)
              CODE
            expect(eval_and_collect_notices(code)).to eq(['true'])
          end
        end
      end
    end
  end
end
