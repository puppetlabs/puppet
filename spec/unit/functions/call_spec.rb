require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'matchers/resource'

describe 'the call method' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include Matchers::Resource

  context "should be callable as" do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Puppet[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
    let(:node) { Puppet::Node.new("test", :environment => env) }
    let(:env_dir_files) {
      {
        'modules' => {
          'test' => {
            'functions' => {
              'call_me.pp' => 'function test::call_me() { "called" }',
              'abc.pp'     => 'function test::abc() { "a-b-c" }',
              'dash.pp'    => 'function test::dash() { "-" }'
            }
          }
        }
      }
    }

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    it 'call on a built-in 4x Ruby API function' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[a]')
          $a = call('split', 'a-b-c', '-')
          notify { $a[0]: }
        CODE
    end

    it 'call on a Puppet language function with no arguments' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[called]')
        notify { test::call_me(): }
        CODE
    end

    it 'call a Ruby 4x API built-in with block' do
      catalog = compile_to_catalog(<<-CODE, node)
        $a = 'each'
        $b = [1,2,3]
        call($a, $b) |$index, $v| {
          file { "/file_$v": ensure => present }
        }
      CODE

      expect(catalog.resource(:file, "/file_1")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_2")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'call with the calling context' do
      expect(eval_and_collect_notices(<<-CODE, node)).to eq(['a'])
        class a { call('notice', $title) }
        include a
      CODE
    end

    it 'call on a non-existent function name' do
      expect { compile_to_catalog(<<-CODE, node) }.to raise_error(Puppet::Error, /Unknown function/)
        $a = call('not_a_function_name')
        notify { $a: }
      CODE
    end

    it 'call a deferred value' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[a]')
          $d = Deferred('split', ['a-b-c', '-'])
          $a = $d.call()
          notify { $a[0]: }
        CODE
    end

    it 'resolves deferred value arguments in an array when calling a deferred' do
      expect(compile_to_catalog(<<-CODE,node)).to have_resource('Notify[a]')
          $d = Deferred('split', [Deferred('test::abc'), '-'])
          $a = $d.call()
          notify { $a[0]: }
        CODE
    end

    it 'resolves deferred value arguments in a Sensitive when calling a deferred' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[a]')
          function my_split(Sensitive $sensy, $on) { $sensy.unwrap |$x| { split($x, $on) } }
          $d = Deferred('my_split', [ Sensitive(Deferred('test::abc')), '-'])
          $a = $d.call()
          notify { $a[0]: }
        CODE
    end

    it 'resolves deferred value arguments in a Hash when calling a deferred' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[a]')
          function my_split(Hash $hashy, $on) { split($hashy['key'], $on)  }
          $d = Deferred('my_split', [ {'key' => Deferred('test::abc')}, '-'])
          $a = $d.call()
          notify { $a[0]: }
        CODE
    end

    it 'resolves deferred value arguments in a nested structure when calling a deferred' do
      expect(compile_to_catalog(<<-CODE,node)).to have_resource('Notify[a]')
          function my_split(Hash $hashy, Array[Sensitive] $sensy) { split($hashy['key'][0], $sensy[0].unwrap |$x| {$x})  }
          $d = Deferred('my_split', [ {'key' => [Deferred('test::abc')]}, [Sensitive(Deferred('test::dash'))]])
          $a = $d.call()
          notify { $a[0]: }
        CODE
    end

    it 'call dig into a variable' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[value 3]')
          $x = { 'a' => [1,2,3] }
          $d = Deferred('$x', ['a', 2])
          $a = $d.call()
          notify { "value $a": }
        CODE
    end
  end
end
