require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the all method' do
  include PuppetSpec::Compiler

  context "should be callable as" do
    it 'all on an array' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.all |$v| { $v > 0 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'all on an array with index' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [0,2,4]
        $n = $a.all |$i, $v| { $v == $i * 2 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'all on a hash selecting entries' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {0=>0,1=>2,2=>4}
        $n = $a.all |$e| { $e[1] == $e[0]*2 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'all on a hash selecting key and value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {0=>0,1=>2,2=>4}
        $n = $a.all |$k,$v| { $v == $k*2 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end
  end

  context "produces a boolean" do
    it 'true when boolean true is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.all |$v| { true }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'true when truthy is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.all |$v| { 42 }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "true")['ensure']).to eq('present')
    end

    it 'false when truthy is not found (all undef)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.all |$v| { undef }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "false")['ensure']).to eq('present')
    end

    it 'false when truthy is not found (all false)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.all |$v| { false }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "false")['ensure']).to eq('present')
    end

  end
  it_should_behave_like 'all iterative functions argument checks', 'any'
  it_should_behave_like 'all iterative functions hash handling', 'any'

end
