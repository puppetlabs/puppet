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
        file { "/file_$v": making_sure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['making_sure'].should == 'present'
  end

  it 'should filter on enumerable type (Integer)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = Integer[1,10]
      $a.filter |$x|{ $x  % 3 == 0}.each |$v|{
        file { "/file_$v": making_sure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_6")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_9")['making_sure'].should == 'present'
  end

  it 'should filter on enumerable type (Integer) using two args index/value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = Integer[10,18]
      $a.filter |$i, $x|{ $i  % 3 == 0}.each |$v|{
        file { "/file_$v": making_sure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_10")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_13")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_16")['making_sure'].should == 'present'
  end

  it 'should produce an array when acting on an array' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.filter |$x|{ $x  =~ /berry$/}
      file { "/file_${b[0]}": making_sure => present }
      file { "/file_${b[1]}": making_sure => present }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['making_sure'].should == 'present'
  end

  it 'filters on a hash (all berries) by key' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $a.filter |$x|{ $x[0]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": making_sure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawberry")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_blueberry")['making_sure'].should == 'present'
  end

  it 'should produce a hash when acting on a hash' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $b = $a.filter |$x|{ $x[0]  =~ /berry$/}
      file { "/file_${b['strawberry']}": making_sure => present }
      file { "/file_${b['blueberry']}": making_sure => present }
      file { "/file_${b['orange']}": making_sure => present }

    MANIFEST

    catalog.resource(:file, "/file_red")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_blue")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_")['making_sure'].should == 'present'
  end

  it 'filters on a hash (all berries) by value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawb'=>'red berry','blueb'=>'blue berry','orange'=>'orange fruit'}
      $a.filter |$x|{ $x[1]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": making_sure => present }
      }
    MANIFEST

    catalog.resource(:file, "/file_strawb")['making_sure'].should == 'present'
    catalog.resource(:file, "/file_blueb")['making_sure'].should == 'present'
  end

  it_should_behave_like 'all iterative functions argument checks', 'filter'
  it_should_behave_like 'all iterative functions hash handling', 'filter'
end
