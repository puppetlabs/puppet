require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'the reject method' do
  include PuppetSpec::Compiler

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  context "should be callable as" do
    it 'reject on an array (no berries)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = ['strawberry','blueberry','orange']
        $a.reject {|$x| $x  =~ /berry$/}.foreach {|$v| 
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
      catalog.resource(:file, "/file_strawberry").should == nil
    end    
    it 'reject on an array (no berries)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = ['strawberry','blueberry','orange']
        $a.reject {|$x| $foo = $x  =~ /berry$/}.foreach {|$v| 
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_orange")['ensure'].should == 'present'
      catalog.resource(:file, "/file_strawberry").should == nil
    end    
  end
end
