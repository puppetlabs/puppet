require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'the reduce method' do
  include PuppetSpec::Compiler

  before :all do
    # enable switching back 
    @saved_parser = Puppet[:parser]
    # These tests only work with future parser
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
    it 'reduce on an array' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $b = $a.reduce {|$memo, $x| $memo + $x }
        file { "/file_$b": ensure => present }
      MANIFEST

      catalog.resource(:file, "/file_6")['ensure'].should == 'present'
    end    
    it 'reduce on an array with start value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = [1,2,3]
        $b = $a.reduce(4) {|$memo, $x| $memo + $x }
        file { "/file_$b": ensure => present }
      MANIFEST
  
      catalog.resource(:file, "/file_10")['ensure'].should == 'present'
    end    
    it 'reduce on a hash' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a=>1, b=>2, c=>3}
        $start = [ignored, 4]
        $b = $a.reduce {|$memo, $x| ['sum', $memo[1] + $x[1]] }
        file { "/file_${$b[0]}_${$b[1]}": ensure => present }
      MANIFEST
    
      catalog.resource(:file, "/file_sum_6")['ensure'].should == 'present'
    end    
    it 'reduce on a hash with start value' do
      catalog = compile_to_catalog(<<-MANIFEST)
        $a = {a=>1, b=>2, c=>3}
        $start = ['ignored', 4]
        $b = $a.reduce($start) {|$memo, $x| ['sum', $memo[1] + $x[1]] }
        file { "/file_${$b[0]}_${$b[1]}": ensure => present }
      MANIFEST
  
      catalog.resource(:file, "/file_sum_10")['ensure'].should == 'present'
    end    
  end
end
