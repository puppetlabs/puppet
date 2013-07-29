require 'spec_helper'
require 'puppet/pops'

describe 'A Puppet Type' do
  let(:factory) { Puppet::Pops::Types::TypeFactory }

    context 'can be used as a hash-key when the type is' do
    it 'integer' do
      data = { factory.integer => 10 }
      expect(data[factory.integer]).to eql(10)
    end

    it 'float' do
      data = { factory.float => 10 }
      expect(data[factory.float]).to eql(10)
    end

    it 'string' do
      data = { factory.string => 10 }
      expect(data[factory.string]).to eql(10)
    end

    it 'boolean' do
      data = { factory.boolean => 10 }
      expect(data[factory.boolean]).to eql(10)
    end

    it 'pattern' do
      data = { factory.pattern => 10 }
      expect(data[factory.pattern]).to eql(10)
    end

    it 'literal' do
      data = { factory.data => 10 }
      expect(data[factory.data]).to eql(10)
    end

    it 'data' do
      data = { factory.data => 10 }
      expect(data[factory.data]).to eql(10)
    end

    it 'array' do
      data = { factory.array_of_data => 10 }
      expect(data[factory.array_of_data]).to eql(10)
    end

    it 'hash' do
      data = { factory.hash_of_data => 10 }
      expect(data[factory.hash_of_data]).to eql(10)
    end

    it 'ruby class' do
      data = { factory.type_of('Foo') => 10 }
      expect(data[factory.type_of('Foo')]).to eql(10)
    end
  end
end
