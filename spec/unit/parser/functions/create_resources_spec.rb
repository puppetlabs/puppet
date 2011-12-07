require 'puppet'
require 'spec_helper'

describe 'function for dynamically creating resources' do

  def get_scope
    @topscope = Puppet::Parser::Scope.new
    # This is necessary so we don't try to use the compiler to discover our parent.
    @topscope.parent = nil
    @scope = Puppet::Parser::Scope.new
    @scope.compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("floppy", :environment => 'production'))
    @scope.parent = @topscope
    @compiler = @scope.compiler
  end
  before :each do
    get_scope
    Puppet::Parser::Functions.function(:create_resources)
  end

  it "should exist" do
    Puppet::Parser::Functions.function(:create_resources).should == "function_create_resources"
  end
  it 'should require two or three arguments' do
    lambda { @scope.function_create_resources(['foo']) }.should raise_error(ArgumentError, 'create_resources(): wrong number of arguments (1; must be 2 or 3)')
    lambda { @scope.function_create_resources(['foo', 'bar', 'blah', 'baz']) }.should raise_error(ArgumentError, 'create_resources(): wrong number of arguments (4; must be 2 or 3)')
  end
  describe 'when creating native types' do
    before :each do
      Puppet[:code]='notify{test:}'
      get_scope
      @scope.resource=Puppet::Parser::Resource.new('class', 't', :scope => @scope)
    end
    it 'empty hash should not cause resources to be added' do
      @scope.function_create_resources(['file', {}])
      @compiler.catalog.resources.size == 1
    end
    it 'should be able to add' do
      @scope.function_create_resources(['file', {'/etc/foo'=>{'ensure'=>'present'}}])
      @compiler.catalog.resource(:file, "/etc/foo")['ensure'].should == 'present'
    end
    it 'should accept multiple types' do
      type_hash = {}
      type_hash['foo'] = {'message' => 'one'}
      type_hash['bar'] = {'message' => 'two'}
      @scope.function_create_resources(['notify', type_hash])
      @compiler.catalog.resource(:notify, "foo")['message'].should == 'one'
      @compiler.catalog.resource(:notify, "bar")['message'].should == 'two'
    end
    it 'should fail to add non-existing type' do
      lambda { @scope.function_create_resources(['foo', {}]) }.should raise_error(ArgumentError, 'could not create resource of unknown type foo')
    end
    it 'should be able to add edges' do
      @scope.function_create_resources(['notify', {'foo'=>{'require' => 'Notify[test]'}}])
      @scope.compiler.compile
      rg = @scope.compiler.catalog.to_ral.relationship_graph
      test  = rg.vertices.find { |v| v.title == 'test' }
      foo   = rg.vertices.find { |v| v.title == 'foo' }
      test.should be
      foo.should be
      rg.path_between(test,foo).should be
    end
    it 'should account for default values' do
      @scope.function_create_resources(['file', {'/etc/foo'=>{'ensure'=>'present'}, '/etc/baz'=>{'group'=>'food'}}, {'group' => 'bar'}])
      @compiler.catalog.resource(:file, "/etc/foo")['group'].should == 'bar'
      @compiler.catalog.resource(:file, "/etc/baz")['group'].should == 'food'
    end
  end
  describe 'when dynamically creating resource types' do
    before :each do 
      Puppet[:code]=
'define foo($one){notify{$name: message => $one}}
notify{test:}
'
      get_scope
      @scope.resource=Puppet::Parser::Resource.new('class', 't', :scope => @scope)
      Puppet::Parser::Functions.function(:create_resources)
    end
    it 'should be able to create defined resoure types' do
      @scope.function_create_resources(['foo', {'blah'=>{'one'=>'two'}}])
      # still have to compile for this to work...
      # I am not sure if this constraint ruins the tests
      @scope.compiler.compile
      @compiler.catalog.resource(:notify, "blah")['message'].should == 'two'
    end
    it 'should fail if defines are missing params' do
      @scope.function_create_resources(['foo', {'blah'=>{}}])
      lambda { @scope.compiler.compile }.should raise_error(Puppet::ParseError, 'Must pass one to Foo[blah] at line 1')
    end
    it 'should be able to add multiple defines' do
      hash = {}
      hash['blah'] = {'one' => 'two'}
      hash['blaz'] = {'one' => 'three'}
      @scope.function_create_resources(['foo', hash])
      # still have to compile for this to work...
      # I am not sure if this constraint ruins the tests
      @scope.compiler.compile
      @compiler.catalog.resource(:notify, "blah")['message'].should == 'two'
      @compiler.catalog.resource(:notify, "blaz")['message'].should == 'three'
    end
    it 'should be able to add edges' do
      @scope.function_create_resources(['foo', {'blah'=>{'one'=>'two', 'require' => 'Notify[test]'}}])
      @scope.compiler.compile
      rg = @scope.compiler.catalog.to_ral.relationship_graph
      test = rg.vertices.find { |v| v.title == 'test' }
      blah = rg.vertices.find { |v| v.title == 'blah' }
      test.should be
      blah.should be
      # (Yoda speak like we do)
      rg.path_between(test,blah).should be
      @compiler.catalog.resource(:notify, "blah")['message'].should == 'two'
    end
    it 'should account for default values' do
      @scope.function_create_resources(['foo', {'blah'=>{}}, {'one' => 'two'}])
      @scope.compiler.compile
      @compiler.catalog.resource(:notify, "blah")['message'].should == 'two'
    end
  end
  describe 'when creating classes' do
    before :each do
      Puppet[:code]=
'class bar($one){notify{test: message => $one}}
notify{tester:}
'
      get_scope
      @scope.resource=Puppet::Parser::Resource.new('class', 't', :scope => @scope)
      Puppet::Parser::Functions.function(:create_resources)
    end
    it 'should be able to create classes' do
      @scope.function_create_resources(['class', {'bar'=>{'one'=>'two'}}])
      @scope.compiler.compile
      @compiler.catalog.resource(:notify, "test")['message'].should == 'two'
      @compiler.catalog.resource(:class, "bar").should_not be_nil#['message'].should == 'two'
    end
    it 'should fail to create non-existing classes' do
      lambda { @scope.function_create_resources(['class', {'blah'=>{'one'=>'two'}}]) }.should raise_error(ArgumentError ,'could not find hostclass blah')
    end
    it 'should be able to add edges' do
      @scope.function_create_resources(['class', {'bar'=>{'one'=>'two', 'require' => 'Notify[tester]'}}])
      @scope.compiler.compile
      rg = @scope.compiler.catalog.to_ral.relationship_graph
      test   = rg.vertices.find { |v| v.title == 'test' }
      tester = rg.vertices.find { |v| v.title == 'tester' }
      test.should be
      tester.should be
      rg.path_between(tester,test).should be
    end
    it 'should account for default values' do
      @scope.function_create_resources(['class', {'bar'=>{}}, {'one' => 'two'}])
      @scope.compiler.compile
      @compiler.catalog.resource(:notify, "test")['message'].should == 'two'
      @compiler.catalog.resource(:class, "bar").should_not be_nil#['message'].should == 'two'
    end
  end
end
