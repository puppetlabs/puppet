#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/property/deep_hash'

klass = Puppet::Property::DeepHash

describe klass do

  it "should be a subclass of Property" do
    expect(klass.superclass).to eq(Puppet::Property)
  end

  before do
    # Wow that's a messy interface to the resource.
    klass.initvars
    @resource = stub 'resource', :[]= => nil, :property => nil
    @property = klass.new(:resource => @resource)
  end

  describe 'when calling insync' do

    describe 'for plain hashes' do

      it 'is not in sync if hashes do not match' do
        @property.should = { 'name' => 'dummy', 'value' => 'anotherResource' }

        is = { 'name' => 'dummy', 'value' => 'resource' }

        expect(@property.insync?(is)).to be false
      end

      it 'is synced if hashes are equal' do
        @property.should = { 'name' => 'dummy', 'value' => 'resource' }

        is = { 'name' => 'dummy', 'value' => 'resource' }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if hashes are equal including array values' do
        @property.should = { 'name' => 'dummy', 'value' => %w(a b c) }

        is = { 'value' => %w(a b c), 'name' => 'dummy' }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if there are unmanaged properties' do
        @property.should = { 'name' => 'dummy' }

        is = { 'name' => 'dummy', 'port' => 8080, 'enabled' => false }
        expect(@property.insync?(is)).to be true
      end

      it 'is in sync if _should_ is undef and _is_ is nil' do
        @property.should = { 'name' => 'dummy', 'value' => :undef }

        is = { 'name' => 'dummy', 'value' => nil }

        expect(@property.insync?(is)).to be true 
      end

    end

    describe 'for nested hashes' do

      it 'is not in sync if nested hashes do not match' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'my-resource' => 'match' } }

        is = { 'name' => 'dummy', 'nested-hash' => { 'my-resource' => 'matchzzz' } }

        expect(@property.insync?(is)).to be false
      end

      it 'is synced if nested hashes are equal' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'my-resource' => 'match' } }

        is = { 'name' => 'dummy', 'nested-hash' => { 'my-resource' => 'match' } }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if hashes are equal but in different order' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'my-resource' => 'match', 'a-resource' => 'default' }, 'value' => 'resource' }

        is = { 'value' => 'resource', 'name' => 'dummy', 'nested-hash' => { 'a-resource' => 'default', 'my-resource' => 'match' } }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if hashes and inner arrays are equal' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'value' => %w(a b c) } }

        is = { 'nested-hash' => { 'value' => %w(a b c) }, 'name' => 'dummy' }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if hashes and typed inner arrays are equal' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'value' => [true, false, true] } }

        is = { 'nested-hash' => { 'value' => [true, false, true] }, 'name' => 'dummy' }

        expect(@property.insync?(is)).to be true
      end

      it 'is synced if there are unmanaged properties' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'enabled' => true } }

        is = { 'name' => 'dummy', 'port' => 8080, 'enabled' => false, 'nested-hash' => { 'enabled' => true, 'a-numeric-resource' => 42 } }
        expect(@property.insync?(is)).to be true
      end

      it 'is synced if there are unmanaged hash properties' do
        @property.should = { 'name' => 'dummy' }

        is = { 'name' => 'dummy', 'port' => 8080, 'enabled' => false, 'nested-hash' => { 'enabled' => true, 'a-numeric-resource' => 42 } }
        expect(@property.insync?(is)).to be true
      end

      it 'is synced if there are unmanaged properties' do
        @property.should = { 'name' => 'dummy', 'nested-hash' => { 'enabled' => true } }

        is = { 'name' => 'dummy', 'port' => 8080, 'enabled' => false, 'nested-hash' => { 'enabled' => true, 'a-numeric-resource' => 42 } }
        expect(@property.insync?(is)).to be true
      end

    end
  end
end
