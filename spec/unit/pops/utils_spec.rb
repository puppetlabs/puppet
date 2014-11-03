require 'spec_helper'
require 'puppet/pops'

describe 'pops utils' do
  context 'when converting strings to numbers' do
    it 'should convert "0" to 0' do
      expect(Puppet::Pops::Utils.to_n("0")).to eq(0)
    end

    it 'should convert "0" to 0 with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("0")).to eq([0, 10])
    end

    it 'should convert "0.0" to 0.0' do
      expect(Puppet::Pops::Utils.to_n("0.0")).to eq(0.0)
    end

    it 'should convert "0.0" to 0.0 with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("0.0")).to eq([0.0, 10])
    end

    it 'should convert "0.01e1" to 0.01e1' do
      expect(Puppet::Pops::Utils.to_n("0.01e1")).to eq(0.01e1)
      expect(Puppet::Pops::Utils.to_n("0.01E1")).to eq(0.01e1)
    end

    it 'should convert "0.01e1" to 0.01e1 with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("0.01e1")).to eq([0.01e1, 10])
      expect(Puppet::Pops::Utils.to_n_with_radix("0.01E1")).to eq([0.01e1, 10])
    end

    it 'should not convert "0e1" to floating point' do
      expect(Puppet::Pops::Utils.to_n("0e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n("0E1")).to be_nil
    end

    it 'should not convert "0e1" to floating point with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("0e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n_with_radix("0E1")).to be_nil
    end

    it 'should not convert "0.0e1" to floating point' do
      expect(Puppet::Pops::Utils.to_n("0.0e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n("0.0E1")).to be_nil
    end

    it 'should not convert "0.0e1" to floating point with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("0.0e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n_with_radix("0.0E1")).to be_nil
    end

    it 'should not convert "000000.0000e1" to floating point' do
      expect(Puppet::Pops::Utils.to_n("000000.0000e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n("000000.0000E1")).to be_nil
    end

    it 'should not convert "000000.0000e1" to floating point with radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("000000.0000e1")).to be_nil
      expect(Puppet::Pops::Utils.to_n_with_radix("000000.0000E1")).to be_nil
    end

    it 'should not convert infinite values to floating point' do
      expect(Puppet::Pops::Utils.to_n("4e999")).to be_nil
    end

    it 'should not convert infinite values to floating point with_radix' do
      expect(Puppet::Pops::Utils.to_n_with_radix("4e999")).to be_nil
    end
  end
end