require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'unit/parser/methods/shared'

describe 'the filter method' do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = 'future'
  end

  it 'should filter on an array (all berries)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $a.filter |$x|{ $x  =~ /berry$/}.each |$v|{
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['ensure'].should == 'present'
  end

  it 'should produce an array when acting on an array' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.filter |$x|{ $x  =~ /berry$/}
      file { "/file_${b[0]}": ensure => present }
      file { "/file_${b[1]}": ensure => present }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['ensure'].should == 'present'
  end

  it 'filters on a hash (all berries) by key' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $a.filter |$x|{ $x[0]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['ensure'].should == 'present'
  end

  it 'should produce a hash when acting on a hash' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $b = $a.filter |$x|{ $x[0]  =~ /berry$/}
      file { "/file_${b['strawberry']}": ensure => present }
      file { "/file_${b['blueberry']}": ensure => present }
      file { "/file_${b['orange']}": ensure => present }

    MANIFEST

    catalog.resource(:file, "/file_red")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blue")['ensure'].should == 'present'
    catalog.resource(:file, "/file_")['ensure'].should == 'present'
  end

  it 'filters on a hash (all berries) by value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawb'=>'red berry','blueb'=>'blue berry','orange'=>'orange fruit'}
      $a.filter |$x|{ $x[1]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawb")['ensure'].should == 'present'
    catalog.resource(:file, "/file_blueb")['ensure'].should == 'present'
  end

  it_should_behave_like 'all iterative functions argument checks', 'filter'
  it_should_behave_like 'all iterative functions hash handling', 'filter'
end
