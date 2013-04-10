require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'unit/parser/methods/shared'

describe 'the select method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = 'future'
  end

  it 'should select on an array (all berries)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $a.select {|$x| $x  =~ /berry$/}.foreach {|$v|
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['ensure'].should == 'present'
  end

  it 'selects on a hash (all berries) by key' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $a.select {|$x| $x[0]  =~ /berry$/}.foreach {|$v|
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['ensure'].should == 'present'
  end

  it 'selects on a hash (all berries) by value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawb'=>'red berry','blueb'=>'blue berry','orange'=>'orange fruit'}
      $a.select {|$x| $x[1]  =~ /berry$/}.foreach {|$v|
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawb")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueb")['ensure'].should == 'present'
  end

  it_should_behave_like 'all iterative functions argument checks', 'select'
  it_should_behave_like 'all iterative functions hash handling', 'select'
end
