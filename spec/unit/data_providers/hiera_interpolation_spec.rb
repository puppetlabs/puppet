#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet'
require 'puppet/data_providers/hiera_config'
require 'puppet/data_providers/hiera_interpolate'

describe "Puppet::DataProviders::HieraInterpolate" do

  context "when there are empty interpolations %{} in data" do

    let(:scope) { {} }
    let(:lookup_invocation) {
      Puppet::Pops::Lookup::Invocation.new(
        scope, {}, {}, nil)
    }
    let(:interpolator) { Class.new { include Puppet::DataProviders::HieraInterpolate }.new }
    let(:empty_interpolation) {'clown%{}shoe'}
    let(:empty_interpolation_as_escape) {'clown%%{}{shoe}s'}
    let(:only_empty_interpolation) {'%{}'}
    let(:empty_namespace) {'%{::}'}
    let(:whitespace1) {'%{ :: }'}
    let(:whitespace2) {'%{   }'}

    it 'should should produce an empty string for the interpolation' do
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
