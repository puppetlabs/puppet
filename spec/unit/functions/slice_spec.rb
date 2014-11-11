require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'methods' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  context "should be callable on array as" do

    it 'slice with explicit parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |$k,$v| {
          file { "/file_${$k}": ensure => $v }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_2]").with_parameter(:ensure, 'absent')
      expect(catalog).to have_resource("File[/file_3]").with_parameter(:ensure, 'present')
    end

    it 'slice with captures last' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |*$kv| {
          file { "/file_${$kv[0]}": ensure => $kv[1] }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_2]").with_parameter(:ensure, 'absent')
      expect(catalog).to have_resource("File[/file_3]").with_parameter(:ensure, 'present')
    end

    it 'slice with one parameter' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |$k| {
          file { "/file_${$k[0]}": ensure => $k[1] }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_2]").with_parameter(:ensure, 'absent')
      expect(catalog).to have_resource("File[/file_3]").with_parameter(:ensure, 'present')
    end

    it 'slice with shorter last slice' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, present, 3, absent]
        $a.slice(4) |$a, $b, $c, $d| {
          file { "/file_$a.$c": ensure => $b }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1.2]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_3.]").with_parameter(:ensure, 'absent')
    end
  end

  context "should be callable on hash as" do
    it 'slice with explicit parameters, missing are empty' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {1=>present, 2=>present, 3=>absent}
        $a.slice(2) |$a,$b| {
          file { "/file_${a[0]}.${b[0]}": ensure => $a[1] }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1.2]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_3.]").with_parameter(:ensure, 'absent')
    end
  end

  context "should be callable on enumerable types as" do
    it 'slice with integer range' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = Integer[1,4]
        $a.slice(2) |$a,$b| {
          file { "/file_${a}.${b}": ensure => present }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1.2]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_3.4]").with_parameter(:ensure, 'present')
    end

    it 'slice with integer' do
      catalog = compile_to_catalog(<<-MANIFEST)
        4.slice(2) |$a,$b| {
          file { "/file_${a}.${b}": ensure => present }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_0.1]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_2.3]").with_parameter(:ensure, 'present')
    end

    it 'slice with string' do
      catalog = compile_to_catalog(<<-MANIFEST)
        'abcd'.slice(2) |$a,$b| {
          file { "/file_${a}.${b}": ensure => present }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_a.b]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_c.d]").with_parameter(:ensure, 'present')
    end
  end

  context "when called without a block" do
    it "should produce an array with the result" do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2).each |$k| {
          file { "/file_${$k[0]}": ensure => $k[1] }
        }
      MANIFEST

      expect(catalog).to have_resource("File[/file_1]").with_parameter(:ensure, 'present')
      expect(catalog).to have_resource("File[/file_2]").with_parameter(:ensure, 'absent')
      expect(catalog).to have_resource("File[/file_3]").with_parameter(:ensure, 'present')
    end
  end
end
