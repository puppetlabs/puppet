require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'rubygems'

describe 'methods' do
  include PuppetSpec::Compiler

  before :all do
    # enable switching back 
    @saved_parser = Puppet[:parser]
    # These tests only work with future parser
    Puppet[:parser] = 'future'
  end
  after :all do
    # switch back to original 
    Puppet[:parser] = @saved_parser
  end

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
    Puppet[:parser] = 'future'
  end

  context "should be callable on array as" do

    it 'slice with explicit parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |$k,$v| {
          file { "/file_${$k}": ensure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
    it 'slice with one parameter' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |$k| {
          file { "/file_${$k[0]}": ensure => $k[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
    it 'slice with shorter last slice' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, present, 3, absent]
        $a.slice(4) |$a, $b, $c, $d| {
          file { "/file_$a.$c": ensure => $b }
        }
      MANIFEST

      catalog.resource(:file, "/file_1.2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3.")['ensure'].should == 'absent'
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

      catalog.resource(:file, "/file_1.2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3.")['ensure'].should == 'absent'
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

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'

    end
  end
end
