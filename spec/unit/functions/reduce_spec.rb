require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'shared_behaviours/iterative_functions'

describe 'the reduce method' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  context "should be callable as" do
    it 'reduce on an array' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $b = $a.reduce |$memo, $x| { $memo + $x }
        file { "/file_$b": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_6]").with_parameter(:ensure, 'present')
    end

    it 'reduce on an array with captures rest in lambda' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $b = $a.reduce |*$mx| { $mx[0] + $mx[1] }
        file { "/file_$b": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_6]").with_parameter(:ensure, 'present')
    end

    it 'reduce on enumerable type' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = Integer[1,3]
        $b = $a.reduce |$memo, $x| { $memo + $x }
        file { "/file_$b": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_6]").with_parameter(:ensure, 'present')
    end

    it 'reduce on an array with start value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $b = $a.reduce(4) |$memo, $x| { $memo + $x }
        file { "/file_$b": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_10]").with_parameter(:ensure, 'present')
    end

    it 'reduce on a hash' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a=>1, b=>2, c=>3}
        $start = [ignored, 4]
        $b = $a.reduce |$memo, $x| {['sum', $memo[1] + $x[1]] }
        file { "/file_${$b[0]}_${$b[1]}": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_sum_6]").with_parameter(:ensure, 'present')
    end

    it 'reduce on a hash with start value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a=>1, b=>2, c=>3}
        $start = ['ignored', 4]
        $b = $a.reduce($start) |$memo, $x| { ['sum', $memo[1] + $x[1]] }
        file { "/file_${$b[0]}_${$b[1]}": ensure => present }
      MANIFEST

      expect(catalog).to have_resource("File[/file_sum_10]").with_parameter(:ensure, 'present')
    end
  end

  it_should_behave_like 'all iterative functions argument checks', 'reduce'

end
