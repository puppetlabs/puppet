require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'rubygems'

describe 'methods' do
  include PuppetSpec::Compiler

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  context "should be callable on array as" do
    
    it 'each_slice with explicit parameters' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.each_slice(2) |$k,$v| { 
          file { "/file_${$k}": ensure => $v }
        }
      MANIFEST
  
      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
    it 'each_slice with one parameter' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, absent, 3, present]
        $a.each_slice(2) |$k| { 
          file { "/file_${$k[0]}": ensure => $k[1] }
        }
      MANIFEST
  
      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
    it 'each_slice with shorter last slice' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, present, 2, present, 3, absent]
        $a.each_slice(4) |$a, $b, $c, $d| { 
          file { "/file_$a.$c": ensure => $b }
        }
      MANIFEST
    
      catalog.resource(:file, "/file_1.2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3.")['ensure'].should == 'absent'
    end
  end
  context "should be callable on hash as" do
    
    it 'each_slice with explicit parameters, missing are empty' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {1=>present, 2=>present, 3=>absent}
        $a.each_slice(2) |$a,$b| { 
          file { "/file_${a[0]}.${b[0]}": ensure => $a[1] }
        }
      MANIFEST
  
      catalog.resource(:file, "/file_1.2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3.")['ensure'].should == 'absent'
    end
  
  end
end
