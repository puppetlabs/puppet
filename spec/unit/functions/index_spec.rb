require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the index function' do
  include PuppetSpec::Compiler

  context "should be callable on Array with" do
    it 'a lambda to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.index |$v| { $v == 2 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "1")['ensure']).to eq('present')
    end

    it 'a lambda taking two arguments to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [6,6,6]
        $n = $a.index |$i, $v| { $i == 2 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end

    it 'a given value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.index(3)
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end
  end

  context "should be callable on Hash with" do
    it 'a lambda to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $h = {1 => 10, 2 => 20, 3 => 30 }
        $n = $h.index |$v| { $v == 20 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end

    it 'a lambda taking two arguments to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $h = {1 => 10, 2 => 20, 3 => 30 }
        $n = $h.index |$k, $v| { $k == 3 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "3")['ensure']).to eq('present')
    end

    it 'a given value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $h = {1 => 10, 2 => 20, 3 => 30 }
        $n = $h.index(20)
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end
  end

  context "should be callable on String with" do
    it 'a lambda to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuu"
        $n = $s.index |$v| { $v == 'o' }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "1")['ensure']).to eq('present')
    end

    it 'a lambda taking two arguments to compute match' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuu"
        $n = $s.index |$i, $v| { $i == 2 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end

    it 'a given value returns index of first found substring given as a string' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuu"
        $n = $s.index('fu')
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "6")['ensure']).to eq('present')
    end

    it 'a given value returns index of first found substring given as a regexp' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuub"
        $n = $s.index(/f(oo|uu)b/)
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "0")['ensure']).to eq('present')
    end
  end

  context "should be callable on an iterable" do
    it 'for example a reverse_each' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.reverse_each.index |$v| { $v == 1 }
        file { "$n": ensure => present }
      MANIFEST
      expect(catalog.resource(:file, "2")['ensure']).to eq('present')
    end
  end

  context 'stops iteration when result is known' do
    it 'true when boolean true is found' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.index |$i, $v| { if $i == 0 { true } else { fail("unwanted") } }
        file { "$n": ensure => present }
      MANIFEST

      expect(catalog.resource(:file, "0")['ensure']).to eq('present')
    end
  end

  context 'returns undef when value is not found' do
    it 'when using array and a lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.index |$v| { $v == 'blue' }
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end

    it 'when using array and a value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $n = $a.index('blue')
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end

    it 'when using a hash and a lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $h = {1 => 10, 2 => 20, 3 => 30}
        $n = $h.index |$v| { $v == 'blue' }
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end

    it 'when using a hash and a value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $h = {1 => 10, 2 => 20, 3 => 30}
        $n = $h.index('blue')
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end

    it 'when using a String and a lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuub"
        $n = $s.index() |$v| { false }
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end

    it 'when using a String and a value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $s = "foobarfuub"
        $n = $s.index('banana')
        file { "test": ensure => if $n =~ Undef { present } else {absent} }
      MANIFEST
      expect(catalog.resource(:file, "test")['ensure']).to eq('present')
    end
  end
end
