require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the each method' do
  include PuppetSpec::Compiler

  context "should be callable as" do
    it 'each on an array selecting each value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.each |$v| {
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_1")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_2")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'each on an array selecting each value - function call style' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        each ($a) |$index, $v| {
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_1")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_2")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'each on an array with index' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [present, absent, present]
        $a.each |$k,$v| {
          file { "/file_${$k+1}": ensure => $v }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_1")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_2")['ensure']).to eq('absent')
      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'each on a hash selecting entries' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'present','b'=>'absent','c'=>'present'}
        $a.each |$e| {
        file { "/file_${e[0]}": ensure => $e[1] }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_a")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_b")['ensure']).to eq('absent')
      expect(catalog.resource(:file, "/file_c")['ensure']).to eq('present')
    end

    it 'each on a hash selecting key and value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>present,'b'=>absent,'c'=>present}
        $a.each |$k, $v| {
          file { "/file_$k": ensure => $v }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_a")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_b")['ensure']).to eq('absent')
      expect(catalog.resource(:file, "/file_c")['ensure']).to eq('present')
    end

    it 'each on a hash selecting key and value (using captures-last parameter)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>present,'b'=>absent,'c'=>present}
        $a.each |*$kv| {
          file { "/file_${kv[0]}": ensure => $kv[1] }
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_a")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_b")['ensure']).to eq('absent')
      expect(catalog.resource(:file, "/file_c")['ensure']).to eq('present')
    end
  end

  context "should produce receiver" do
    it 'each checking produced value using single expression' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, 3, 2]
        $b = $a.each |$x| { "unwanted" }
        file { "/file_${b[1]}":
          ensure => present
        }
      MANIFEST

      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

  end
  it_should_behave_like 'all iterative functions argument checks', 'each'
  it_should_behave_like 'all iterative functions hash handling', 'each'

end
