require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Time
describe 'Timespan' do
  include PuppetSpec::Compiler

  let! (:simple) { Timespan.from_fields(false, 1, 3, 10, 11) }
  let! (:all_fields_hash) { {'days' => 1, 'hours' => 7, 'minutes' => 10, 'seconds' => 11, 'milliseconds' => 123, 'microseconds' => 456, 'nanoseconds' => 789} }
  let! (:complex) { Timespan.from_fields_hash(all_fields_hash) }

  context 'can be created from a String' do
    it 'using default format' do
      expect(Timespan.parse('1-03:10:11')).to eql(simple)
    end

    it 'using explicit format' do
      expect(Timespan.parse('1-7:10:11.123456789', '%D-%H:%M:%S.%N')).to eql(complex)
    end

    it 'using leading minus and explicit format' do
      expect(Timespan.parse('-1-7:10:11.123456789', '%D-%H:%M:%S.%N')).to eql(-complex)
    end

    it 'using %H as the biggest quantity' do
      expect(Timespan.parse('27:10:11', '%H:%M:%S')).to eql(simple)
    end

    it 'using %M as the biggest quantity' do
      expect(Timespan.parse('1630:11', '%M:%S')).to eql(simple)
    end

    it 'using %S as the biggest quantity' do
      expect(Timespan.parse('97811', '%S')).to eql(simple)
    end

    it 'using %L as the biggest quantity' do
      expect(Timespan.parse('97811000', '%L')).to eql(simple)
    end

    it 'using %N as the biggest quantity' do
      expect(Timespan.parse('112211123456789', '%N')).to eql(complex)
    end

    it 'where biggest quantity is not frist' do
      expect(Timespan.parse('11:1630', '%S:%M')).to eql(simple)
    end
  end

  context 'when presented as a String' do
    it 'uses default format for #to_s' do
      expect(simple.to_s).to eql('1-03:10:11')
    end

    context 'using a format' do
      it 'produces a string containing all components' do
        expect(complex.format('%D-%H:%M:%S.%N')).to eql('1-07:10:11.123456789')
      end

      it 'produces a literal % for %%' do
        expect(complex.format('%D%%%H:%M:%S')).to eql('1%07:10:11')
      end

      it 'produces a leading dash for negative instance' do
        expect((-complex).format('%D-%H:%M:%S')).to eql('-1-07:10:11')
      end
    end
  end

  context 'when converted to a hash' do
    it 'produces a hash with all numeric keys' do
      hash = complex.to_hash
      expect(hash).to eql(all_fields_hash)
    end

    it 'produces a compact hash with seconds and nanoseconds for #to_hash(true)' do
      hash = complex.to_hash(true)
      expect(hash).to eql({'seconds' => 112211, 'nanoseconds' => 123456789})
    end

    context 'from a negative value' do
      it 'produces a hash with all numeric keys and negative = true' do
        hash = (-complex).to_hash
        expect(hash).to eql(all_fields_hash.merge('negative' => true))
      end

      it 'produces a compact hash with negative seconds and negative nanoseconds for #to_hash(true)' do
        hash = (-complex).to_hash(true)
        expect(hash).to eql({'seconds' => -112211, 'nanoseconds' => -123456789})
      end
    end
  end
end
end
end
