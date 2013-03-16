require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'rubygems'

describe 'methods' do
  include PuppetSpec::Compiler

  before :all do
    # enable switching back 
    @saved_parser = Puppet[:parser]
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

  context "should be callable as" do
    it 'each on an array selecting each value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $a.each |$v| { 
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end
    it 'each on an array selecting each value - function call style' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        foreach ($a) |$index, $v| => { 
          file { "/file_$v": ensure => present }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'present'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

    it 'each on an array with index' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [present, absent, present]
        $a.each |$k,$v| { 
          file { "/file_${$k+1}": ensure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_1")['ensure'].should == 'present'
      catalog.resource(:file, "/file_2")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

    it 'each on a hash selecting entries' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>'present','b'=>'absent','c'=>'present'}
        $a.each |$e| { 
        file { "/file_${e[0]}": ensure => $e[1] }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['ensure'].should == 'present'
      catalog.resource(:file, "/file_b")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_c")['ensure'].should == 'present'
    end
    it 'each on a hash selecting key and value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {'a'=>present,'b'=>absent,'c'=>present}
        $a.each |$k, $v| { 
          file { "/file_$k": ensure => $v }
        }
      MANIFEST

      catalog.resource(:file, "/file_a")['ensure'].should == 'present'
      catalog.resource(:file, "/file_b")['ensure'].should == 'absent'
      catalog.resource(:file, "/file_c")['ensure'].should == 'present'
    end
  end
  context "should produce receiver" do
    it 'each checking produced value using single expression' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1, 3, 2]
        $b = $a.each |$x| { $x }
        file { "/file_${b[1]}":
          ensure => present
        }
      MANIFEST

      catalog.resource(:file, "/file_3")['ensure'].should == 'present'
    end

  end
end
