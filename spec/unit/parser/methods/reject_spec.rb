require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'unit/parser/methods/shared'

describe 'the reject method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = 'future'
  end

  it 'rejects on an array (no berries)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $a.reject {|$x| $x  =~ /berry$/}.foreach {|$v|
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
    catalog.resource(:file, "/file_strawberry").should == nil
  end

  it 'produces an array when acting on an array' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.reject {|$x| $x  =~ /berry$/}
      file { "/file_${b[0]}": ensure => present }

    MANIFEST

    catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
    catalog.resource(:file, "/file_strawberry").should == nil
  end

  it 'rejects on a hash (all berries) by key' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $a.reject {|$x| $x[0]  =~ /berry$/}.foreach {|$v|
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
  end

  it 'produces a hash when acting on a hash' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','grape'=>'purple'}
      $b = $a.reject {|$x| $x[0]  =~ /berry$/}
      file { "/file_${b[grape]}": ensure => present }

    MANIFEST

    catalog.resource(:file, "/file_purple")['ensure'].should == 'present'
  end

  it 'rejects on a hash (all berries) by value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawb'=>'red berry','blueb'=>'blue berry','orange'=>'orange fruit'}
      $a.reject {|$x| $x[1]  =~ /berry$/}.foreach {|$v|
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
  end

  it_should_behave_like 'all iterative functions argument checks', 'reject'
  it_should_behave_like 'all iterative functions hash handling', 'reject'
end
