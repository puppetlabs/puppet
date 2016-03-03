#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet'
require 'puppet/data_providers/hiera_config'
require 'puppet/data_providers/hiera_interpolate'

describe "Puppet::DataProviders::HieraInterpolate" do

  let(:interpolator) { Class.new { include Puppet::DataProviders::HieraInterpolate }.new }
  let(:scope) { {} }
  let(:lookup_invocation) { Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, nil) }

  context 'when interpolating nested data' do
    let(:nested_hash) { { 'a' => { 'aa' => "%{alias('aaa')}" } } }

    it 'produces a nested hash with arrays from nested aliases with hashes and arrays' do
      Puppet::Pops::Lookup.expects(:lookup).with('aaa', nil, '', true, nil, lookup_invocation).returns({ 'b' => { 'bb' => "%{alias('bbb')}" } })
      Puppet::Pops::Lookup.expects(:lookup).with('bbb', nil, '', true, nil, lookup_invocation).returns([ "%{alias('ccc')}" ])
      Puppet::Pops::Lookup.expects(:lookup).with('ccc', nil, '', true, nil, lookup_invocation).returns('text')
      expect(interpolator.interpolate(nested_hash, lookup_invocation, true)).to eq('a'=>{'aa'=>{'b'=>{'bb'=>['text']}}})
    end
  end

  context 'when there are empty interpolations %{} in data' do

    let(:empty_interpolation) {'clown%{}shoe'}
    let(:empty_interpolation_as_escape) {'clown%%{}{shoe}s'}
    let(:only_empty_interpolation) {'%{}'}
    let(:empty_namespace) {'%{::}'}
    let(:whitespace1) {'%{ :: }'}
    let(:whitespace2) {'%{   }'}

    it 'should produce an empty string for the interpolation' do
      expect(interpolator.interpolate(empty_interpolation, lookup_invocation, true)).to eq('clownshoe')
    end

    it 'the empty interpolation can be used as an escape mechanism' do
      expect(interpolator.interpolate(empty_interpolation_as_escape, lookup_invocation, true)).to eq('clown%{shoe}s')
    end

    it 'the value can consist of only an empty escape' do
      expect(interpolator.interpolate(only_empty_interpolation, lookup_invocation, true)).to eq('')
    end

    it 'the value can consist of an empty namespace %{::}' do
      expect(interpolator.interpolate(empty_namespace, lookup_invocation, true)).to eq('')
    end

    it 'the value can consist of whitespace %{ :: }' do
      expect(interpolator.interpolate(whitespace1, lookup_invocation, true)).to eq('')
    end

    it 'the value can consist of whitespace %{  }' do
      expect(interpolator.interpolate(whitespace2, lookup_invocation, true)).to eq('')
    end
  end
end
