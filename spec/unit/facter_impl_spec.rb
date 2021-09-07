require 'spec_helper'

describe 'Puppet::FacterImpl' do
  subject(:facter_impl) { Puppet::FacterImpl.new }

  it { is_expected.to respond_to(:value) }
  it { is_expected.to respond_to(:add) }

  describe '.value' do
    let(:method_name) { :value }

    before { allow(Facter).to receive(method_name) }

    it 'delegates to Facter API' do
      facter_impl.value('test_fact')
      expect(Facter).to have_received(method_name).with('test_fact')
    end
  end

  describe '.add' do
    let(:block) { Proc.new { setcode 'test' } }
    let(:method_name) { :add }

    before { allow(Facter).to receive(method_name) }

    it 'delegates to Facter API' do
      facter_impl.add('test_fact', &block)
      expect(Facter).to have_received(method_name).with('test_fact', &block)
    end
  end
end
