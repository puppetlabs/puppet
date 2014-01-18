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
          file { "/file_${$k}": making_sure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end

    it 'slice with one parameter' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2) |$k| {
          file { "/file_${$k[0]}": making_sure => $k[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'
    end

    it 'slice with shorter last slice' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, present, 3, absent]
        $a.slice(4) |$a, $b, $c, $d| {
          file { "/file_$a.$c": making_sure => $b }
        }
      MANIFEST

      catalog.resource(:file, "/file_1.2")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_3.")['making_sure'].should == 'absent'
    end
  end

  context "should be callable on hash as" do
    it 'slice with explicit parameters, missing are empty' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {1=>present, 2=>present, 3=>absent}
        $a.slice(2) |$a,$b| {
          file { "/file_${a[0]}.${b[0]}": making_sure => $a[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_1.2")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_3.")['making_sure'].should == 'absent'
    end
  end

  context "should be callable on enumerable type as" do
    it 'slice with explicit parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = Integer[1,4]
        $a.slice(2) |$a,$b| {
          file { "/file_${a}.${b}": making_sure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1.2")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_3.4")['making_sure'].should == 'present'
    end
  end

  context "when called without a block" do
    it "should produce an array with the result" do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.slice(2).each |$k| {
          file { "/file_${$k[0]}": making_sure => $k[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['making_sure'].should == 'present'
      catalog.resource(:file, "/file_2")['making_sure'].should == 'absent'
      catalog.resource(:file, "/file_3")['making_sure'].should == 'present'

    end
  end
end
