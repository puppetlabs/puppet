require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Types
describe 'The Object Type' do

  context 'when parsed by the EvaluatingParser' do
    let(:parser) { TypeParser.new }
    let(:pp_parser) { Puppet::Pops::Parser::EvaluatingParser.new }
    let(:scope) { Object.new }
    let(:loader) { Object.new }

    before(:each) do
      Adapters::LoaderAdapter.expects(:loader_for_model_object).with(instance_of(Model::QualifiedReference), scope).
        at_least_once.returns loader
    end

    let(:object) { type_object_t('MyObject', nil, '{ a => Integer, b => Callable }') }

    def type_object_t(name, inherits, body_string)
      preamble = inherits.nil? ? '[' : "[#{inherits},"
      TypeFactory.type_alias(name, pp_parser.parse_string("Object#{preamble}#{body_string}]").current)
    end

    before(:each) do
      loader.expects(:load).with(:type, 'myobject').at_least_once.returns object
    end

    it 'can be loaded by the TypeParser' do
      tp = parser.parse('MyObject', scope)
      expect(tp).to eql(object)
    end

    it 'have members with expected name and type' do
      tp = parser.parse('MyObject', scope).resolved_type
      expect(tp.members).to be_a(PStructType)
      expect{ |b| tp.members.each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'b')
      expect{ |b| tp.members.each {|m| m.value_type.simple_name.tap(&b) }}.to yield_successive_args('Integer', 'Callable')
    end

    context 'and inheriting from a another Object type' do
      let(:derived) { type_object_t('MyDerivedObject', 'MyObject', '{ c=> String, d => Boolean }') }

      before(:each) do
        loader.expects(:load).with(:type, 'myderivedobject').at_most_once.returns derived
      end

      it 'includes the inherited type and its members' do
        tp = parser.parse('MyDerivedObject', scope)
        expect(tp).to eql(derived)
        tp = tp.resolved_type
        expect(tp.parent).to eql(object)
        expect{ |b| tp.members.each {|m| m.name.tap(&b) }}.to yield_successive_args('c', 'd')
        expect{ |b| tp.members.each {|m| m.value_type.simple_name.tap(&b) }}.to yield_successive_args('String', 'Boolean')
        expect{ |b| tp.members(true).each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'b', 'c', 'd')
        expect{ |b| tp.members(true).each {|m| m.value_type.simple_name.tap(&b) }}.to(
          yield_successive_args('Integer', 'Callable', 'String', 'Boolean'))
      end

      it 'can redefine inherited member to assignable type' do
        loader.expects(:load).with(:type, 'myderivedobject').returns(
          type_object_t('MyDerivedObject', 'MyObject', '{ a=> Integer[0,default], d => Boolean }'))
        tp = parser.parse('MyDerivedObject', scope)
        expect(tp).to eql(derived)
        tp = tp.resolved_type
        expect(tp.parent).to eql(object)
        expect{ |b| tp.members.each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'd')
        expect{ |b| tp.members.each {|m| m.value_type.to_s.tap(&b) }}.to yield_successive_args('Integer[0, default]', 'Boolean')
        expect{ |b| tp.members(true).each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'b', 'd')
        expect{ |b| tp.members(true).each {|m| m.value_type.to_s.tap(&b) }}.to(
          yield_successive_args('Integer[0, default]', 'Callable', 'Boolean'))
      end

      it 'can not redefine inherited member to a unassignable type' do
        loader.expects(:load).with(:type, 'myderivedobject').returns(
          type_object_t('MyDerivedObject', 'MyObject', '{ a=> String, d => Boolean }'))
        expect { parser.parse('MyDerivedObject', scope) }.to raise_error(Puppet::Error, /redefines inherited member/)
      end

      it 'will be assignable to its inherited type' do
        tp = parser.parse('MyDerivedObject', scope)
        expect(object).to be_assignable(tp)
      end

      it 'will not consider the inherited type to be assignable' do
        tp = parser.parse('MyDerivedObject', scope)
        expect(tp).not_to be_assignable(object)
      end

      context 'that in turn inherits another Object type' do
        let(:derived2) { type_object_t('MyDerivedObject2', 'MyDerivedObject', '{ e => String, f => Boolean }') }

        before(:each) do
          loader.expects(:load).with(:type, 'myderivedobject2').at_most_once.returns derived2
        end

        it 'will be assignable to all inherited types' do
          tp = parser.parse('MyDerivedObject2', scope)
          expect(object).to be_assignable(tp)
          expect(derived).to be_assignable(tp)
        end

        it 'will not consider any of the inherited types to be assignable' do
          tp = parser.parse('MyDerivedObject2', scope)
          expect(tp).not_to be_assignable(object)
          expect(tp).not_to be_assignable(derived)
        end
      end

      context 'that in turn inherits itself' do
        let(:object) { type_object_t('MyObject', 'MyDerivedObject', '{}') }

        it 'will raise an error' do
          expect { parser.parse('MyObject', scope) }.to raise_error(Puppet::Error, /inherits from itself/)
        end
      end
    end
  end
end
end
end
