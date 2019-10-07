require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the any method' do
  include PuppetSpec::Compiler

  context "should be callable as" do
    it 'any on an array' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.any |$v| { $v == 2 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'any on an array with index' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.any |$i, $v| { $i == 2 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'any on a hash selecting entries' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'ah','b'=>'be','c'=>'ce'}
        $n = $a.any |$e| { $e[1] == 'be' }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'any on a hash selecting key and value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'ah','b'=>'be','c'=>'ce'}
        $n = $a.any |$k, $v| { $v == 'be' }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end
  end

  context 'stops iteration when result is known' do
    it 'true when boolean true is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.any |$v| { if $v == 1 { true } else { fail("unwanted") } }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end
  end

  context "produces a boolean" do
    it 'true when boolean true is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.any |$v| { true }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'true when truthy is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.any |$v| { 42 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'false when truthy is not found (all undef)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.any |$v| { undef }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "false")['ensure']).to eq('present')
    end

    it 'false when truthy is not found (all false)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.any |$v| { false }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "false")['ensure']).to eq('present')
    end

  end
  it_should_behave_like 'all iterative functions argument checks', 'any'
  it_should_behave_like 'all iterative functions hash handling', 'any'

end
