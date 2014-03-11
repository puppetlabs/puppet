require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'unit/parser/methods/shared'

describe 'the map method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = "future"
  end

  context "using future parser" do
    it 'map on an array (multiplying each value by 2)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.map |$x|{ $x*2}.each |$v|{
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_4")['ensure'].should == 'present'
      catalog.resource(:file, "/file_6")['ensure'].should == 'present'
    end

    it 'map on an enumerable type (multiplying each value by 2)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = Integer[1,3]
        $a.map |$x|{ $x*2}.each |$v|{
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_4")['ensure'].should == 'present'
      catalog.resource(:file, "/file_6")['ensure'].should == 'present'
    end

    it 'map on an integer (multiply each by 3)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        3.map |$x|{ $x*3}.each |$v|{
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_0")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
      catalog.resource(:file, "/file_6")['ensure'].should == 'present'
    end

    it 'map on a string' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a=>x, b=>y}
        "ab".map |$x|{$a[$x]}.each |$v|{
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_x")['ensure'].should == 'present'
      catalog.resource(:file, "/file_y")['ensure'].should == 'present'
    end

    it 'map on an array (multiplying value by 10 in even index position)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.map |$i, $x|{ if $i % 2 == 0 {$x} else {$x*10}}.each |$v|{
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_20")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

    it 'map on a hash selecting keys' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.map |$x|{ $x[0]}.each |$k|{
          file { "/file_$k": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['ensure'].should == 'present'
      catalog.resource(:file, "/file_b")['ensure'].should == 'present'
      catalog.resource(:file, "/file_c")['ensure'].should == 'present'
    end

    it 'map on a hash selecting keys - using two block parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.map |$k,$v|{ file { "/file_$k": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['ensure'].should == 'present'
      catalog.resource(:file, "/file_b")['ensure'].should == 'present'
      catalog.resource(:file, "/file_c")['ensure'].should == 'present'
    end

    it 'each on a hash selecting value' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.map |$x|{ $x[1]}.each |$k|{ file { "/file_$k": ensure => present } }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

    it 'each on a hash selecting value - using two bloc parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.map |$k,$v|{ file { "/file_$v": ensure => present } }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

    context "handles data type corner cases" do
      it "map gets values that are false" do
        catalog = compile_to_catalog(<<-MANIFEST)
          $a = [false,false]
          $a.map |$x| { $x }.each |$i, $v| {
            file { "/file_$i.$v": ensure => present }
          }
        MANIFEST

        catalog.resource(:file, "/file_0.false")['ensure'].should == 'present'
        catalog.resource(:file, "/file_1.false")['ensure'].should == 'present'
      end

      it "map gets values that are nil" do
        Puppet::Parser::Functions.newfunction(:nil_array, :type => :rvalue) do |args|
          [nil]
        end
        catalog = compile_to_catalog(<<-MANIFEST)
          $a = nil_array()
          $a.map |$x| { $x }.each |$i, $v| {
            file { "/file_$i.$v": ensure => present }
          }
        MANIFEST

        catalog.resource(:file, "/file_0.")['ensure'].should == 'present'
      end

      it "map gets values that are undef" do
        catalog = compile_to_catalog(<<-MANIFEST)
          $a = [$does_not_exist]
          $a.map |$x = "something"| { $x }.each |$i, $v| {
            file { "/file_$i.$v": ensure => present }
          }
        MANIFEST
        catalog.resource(:file, "/file_0.something")['ensure'].should == 'present'
      end
    end

  context 'map checks arguments and' do
    it 'raises an error when block has more than 2 argument' do
      expect do
        compile_to_catalog(<<-MANIFEST)
          [1].map |$index, $x, $yikes|{  }
        MANIFEST
      end.to raise_error(Puppet::Error, /block must define at most two parameters/)
    end

    it 'raises an error when block has fewer than 1 argument' do
      expect do
        compile_to_catalog(<<-MANIFEST)
          [1].map || {  }
        MANIFEST
      end.to raise_error(Puppet::Error, /block must define at least one parameter/)
    end
  end

  it_should_behave_like 'all iterative functions argument checks', 'map'
  it_should_behave_like 'all iterative functions hash handling', 'map'
  end
end
