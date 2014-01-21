require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'rubygems'

describe 'the each method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = 'future'
  end

  context "should be callable as" do
    it 'each on an array selecting each value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.each |$v| {
          file { "/file_$v": making_sure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end
    it 'each on an array selecting each value - function call style' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        each ($a) |$index, $v| {
          file { "/file_$v": making_sure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end

    it 'each on an array with index' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [present, absent, present]
        $a.each |$k,$v| {
          file { "/file_${$k+1}": making_sure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end

    it 'each on a hash selecting entries' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'present','b'=>'absent','c'=>'present'}
        $a.each |$e| {
        file { "/file_${e[0]}": making_sure => $e[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_b")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_c")['making_sure'].should == 'present'
    end
    it 'each on a hash selecting key and value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>present,'b'=>absent,'c'=>present}
        $a.each |$k, $v| {
          file { "/file_$k": making_sure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_b")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_c")['making_sure'].should == 'present'
    end
  end
  context "should produce receiver" do
    it 'each checking produced value using single expression' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, 3, 2]
        $b = $a.each |$x| { "unwanted" }
        file { "/file_${b[1]}":
          making_sure => present
        }
      MANIFEST

      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end

  end
end
