require 'spec_helper'
require 'puppet/facts'

describe Puppet::Facts do

  describe 'replace_facter' do
    it 'returns false if cfacter feature is not present' do
      Puppet::features.stubs(:cfacter?).returns false
      Puppet::Facts.replace_facter.should be_false
    end

    it 'returns true if cfacter is already enabled' do
      Puppet::features.stubs(:cfacter?).returns true

      facter = Facter
      begin
        CFacter = mock
        Object.send(:remove_const, :Facter)
        Object.send(:const_set, :Facter, CFacter)
        Puppet::Facts.replace_facter.should be_true
      ensure
        Object.send(:remove_const, :CFacter)
        Object.send(:remove_const, :Facter)
        Object.send(:const_set, :Facter, facter)
      end
    end

    it 'replaces facter with cfacter' do
      Puppet.features.stubs(:cfacter?).returns true
      facter = Facter
      external_facts = Puppet.features.external_facts?
      begin
        CFacter = mock
        CFacter.stubs(:version).returns '0.2.0'
        CFacter.stubs(:search).returns nil
        CFacter.stubs(:search_external).returns nil
        CFacter.stubs(:value).with(:somefact).returns 'foo'
        Puppet::Facts.replace_facter
        Facter.should eq CFacter
        Facter.value(:somefact).should eq 'foo'
        Puppet.features.external_facts?.should be_true
      ensure
        Object.send(:remove_const, :CFacter)
        Object.send(:remove_const, :Facter)
        Object.send(:const_set, :Facter, facter)
        Puppet.features.add(:external_facts) { external_facts }
      end
    end

  end

end
