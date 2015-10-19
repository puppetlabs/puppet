require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

require 'shared_behaviours/iterative_functions'

describe 'the filter method' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'should filter on an array (all berries)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $a.filter |$x|{ $x  =~ /berry$/}.each |$v|{
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawberry]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_blueberry]").with_parameter(:ensure, 'present')
  end

  it 'should filter on enumerable type (Integer)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = Integer[1,10]
      $a.filter |$x|{ $x  % 3 == 0}.each |$v|{
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    expect(catalog).to have_resource("File[/file_3]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_6]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_9]").with_parameter(:ensure, 'present')
  end

  it 'should filter on enumerable type (Integer) using two args index/value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = Integer[10,18]
      $a.filter |$i, $x|{ $i  % 3 == 0}.each |$v|{
        file { "/file_$v": ensure => present }
      }
    MANIFEST

    expect(catalog).to have_resource("File[/file_10]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_13]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_16]").with_parameter(:ensure, 'present')
  end

  it 'should produce an array when acting on an array' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.filter |$x|{ $x  =~ /berry$/}
      file { "/file_${b[0]}": ensure => present }
      file { "/file_${b[1]}": ensure => present }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawberry]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_blueberry]").with_parameter(:ensure, 'present')
  end

  it 'can filter array using index and value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.filter |$index, $x|{ $index  == 0 or $index ==2}
      file { "/file_${b[0]}": ensure => present }
      file { "/file_${b[1]}": ensure => present }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawberry]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_orange]").with_parameter(:ensure, 'present')
  end

  it 'can filter array using index and value (using captures-rest)' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = ['strawberry','blueberry','orange']
      $b = $a.filter |*$ix|{ $ix[0]  == 0 or $ix[0] ==2}
      file { "/file_${b[0]}": ensure => present }
      file { "/file_${b[1]}": ensure => present }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawberry]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_orange]").with_parameter(:ensure, 'present')
  end

  it 'filters on a hash (all berries) by key' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $a.filter |$x|{ $x[0]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawberry]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_blueberry]").with_parameter(:ensure, 'present')
  end

  it 'should produce a hash when acting on a hash' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawberry'=>'red','blueberry'=>'blue','orange'=>'orange'}
      $b = $a.filter |$x|{ $x[0]  =~ /berry$/}
      file { "/file_${b['strawberry']}": ensure => present }
      file { "/file_${b['blueberry']}": ensure => present }
      file { "/file_${b['orange']}": ensure => present }

    MANIFEST

    expect(catalog).to have_resource("File[/file_red]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_blue]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_]").with_parameter(:ensure, 'present')
  end

  it 'filters on a hash (all berries) by value' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'strawb'=>'red berry','blueb'=>'blue berry','orange'=>'orange fruit'}
      $a.filter |$x|{ $x[1]  =~ /berry$/}.each |$v|{
        file { "/file_${v[0]}": ensure => present }
      }
    MANIFEST

    expect(catalog).to have_resource("File[/file_strawb]").with_parameter(:ensure, 'present')
    expect(catalog).to have_resource("File[/file_blueb]").with_parameter(:ensure, 'present')
  end

  it 'filters on an array will not include elements for which the block returns truthy but not true' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $r = [1, 2, 3].filter |$v| { $v } == []
      notify { "eval_${$r}": }
    MANIFEST

    expect(catalog).to have_resource('Notify[eval_true]')
  end

  it 'filters on a hash will not include elements for which the block returns truthy but not true' do
    catalog = compile_to_catalog(<<-MANIFEST)
      $r = {a => 1, b => 2, c => 3}.filter |$k, $v| { $v } == {}
      notify { "eval_${$r}": }
    MANIFEST

    expect(catalog).to have_resource('Notify[eval_true]')
  end

  it_should_behave_like 'all iterative functions argument checks', 'filter'
  it_should_behave_like 'all iterative functions hash handling', 'filter'
end
