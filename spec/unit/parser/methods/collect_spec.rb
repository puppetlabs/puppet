require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'the collect method' do
  include PuppetSpec::Compiler

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  context "should be callable as" do
    it 'collect on an array (multiplying each value by 2)' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.collect {|$x| $x*2}.foreach {|$v| 
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_4")['ensure'].should == 'present'
      catalog.resource(:file, "/file_6")['ensure'].should == 'present'
    end
    
    it 'collect on a hash selecting keys' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.collect {|$x| $x[0]}.foreach {|$k| 
          file { "/file_$k": ensure => present }
        }
      MANIFEST
  
      catalog.resource(:file, "/file_a")['ensure'].should == 'present'
      catalog.resource(:file, "/file_b")['ensure'].should == 'present'
      catalog.resource(:file, "/file_c")['ensure'].should == 'present'
    end
    it 'foreach on a hash selecting value' do
      catalog = compile_to_catalog(<<-MANIFEST)
      $a = {'a'=>1,'b'=>2,'c'=>3}
      $a.collect {|$x| $x[1]}.foreach {|$k| 
          file { "/file_$k": ensure => present }
        }
      MANIFEST
  
      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
  end
end
