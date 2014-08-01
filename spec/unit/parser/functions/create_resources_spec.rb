require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

describe 'function for dynamically creating resources' do
  include PuppetSpec::Compiler

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
    Puppet::Parser::Functions.function(:create_resources)
  end

  it "should exist" do
    Puppet::Parser::Functions.function(:create_resources).should == "function_create_resources"
  end

  it 'should require two or three arguments' do
    expect { @scope.function_create_resources(['foo']) }.to raise_error(ArgumentError, 'create_resources(): Wrong number of arguments given (1 for minimum 2)')
    expect { @scope.function_create_resources(['foo', 'bar', 'blah', 'baz']) }.to raise_error(ArgumentError, 'create_resources(): wrong number of arguments (4; must be 2 or 3)')
  end

  it 'should require second argument to be a hash' do
    expect { @scope.function_create_resources(['foo','bar']) }.to raise_error(ArgumentError, 'create_resources(): second argument must be a hash')
  end

  it 'should require optional third argument to be a hash' do
    expect { @scope.function_create_resources(['foo',{},'foo']) }.to raise_error(ArgumentError, 'create_resources(): third argument, if provided, must be a hash')
  end

  describe 'when creating native types' do
    it 'empty hash should not cause resources to be added' do
      noop_catalog = compile_to_catalog("create_resources('file', {})")
      empty_catalog = compile_to_catalog("")
      noop_catalog.resources.size.should == empty_catalog.resources.size
    end

    it 'should be able to add' do
      catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}})")
      catalog.resource(:file, "/etc/foo")['ensure'].should == 'present'
    end

    it 'should be able to add virtual resources' do
      catalog = compile_to_catalog("create_resources('@file', {'/etc/foo'=>{'ensure'=>'present'}})\nrealize(File['/etc/foo'])")
      catalog.resource(:file, "/etc/foo")['ensure'].should == 'present'
    end

    it 'should be able to add exported resources' do
      catalog = compile_to_catalog("create_resources('@@file', {'/etc/foo'=>{'ensure'=>'present'}}) realize(File['/etc/foo'])")
      catalog.resource(:file, "/etc/foo")['ensure'].should == 'present'
      catalog.resource(:file, "/etc/foo").exported.should == true
    end

    it 'should accept multiple types' do
      catalog = compile_to_catalog("create_resources('notify', {'foo'=>{'message'=>'one'}, 'bar'=>{'message'=>'two'}})")
      catalog.resource(:notify, "foo")['message'].should == 'one'
      catalog.resource(:notify, "bar")['message'].should == 'two'
    end

    it 'should fail to add non-existing type' do
      expect do
        @scope.function_create_resources(['create-resource-foo', { 'foo' => {} }])
      end.to raise_error(ArgumentError, /Invalid resource type create-resource-foo/)
    end

    it 'should be able to add edges' do
      rg = compile_to_relationship_graph("notify { test: }\n create_resources('notify', {'foo'=>{'require'=>'Notify[test]'}})")
      test  = rg.vertices.find { |v| v.title == 'test' }
      foo   = rg.vertices.find { |v| v.title == 'foo' }
      test.must be
      foo.must be
      rg.path_between(test,foo).should be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}, '/etc/baz'=>{'group'=>'food'}}, {'group' => 'bar'})")
      catalog.resource(:file, "/etc/foo")['group'].should == 'bar'
      catalog.resource(:file, "/etc/baz")['group'].should == 'food'
    end
  end

  describe 'when dynamically creating resource types' do
    it 'should be able to create defined resource types' do
      catalog = compile_to_catalog(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        create_resources('foocreateresource', {'blah'=>{'one'=>'two'}})
      MANIFEST
      catalog.resource(:notify, "blah")['message'].should == 'two'
    end

    it 'should fail if defines are missing params' do
      expect {
        compile_to_catalog(<<-MANIFEST)
          define foocreateresource($one) {
            notify { $name: message => $one }
          }

          create_resources('foocreateresource', {'blah'=>{}})
        MANIFEST
      }.to raise_error(Puppet::Error, 'Must pass one to Foocreateresource[blah] on node foonode')
    end

    it 'should be able to add multiple defines' do
      catalog = compile_to_catalog(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        create_resources('foocreateresource', {'blah'=>{'one'=>'two'}, 'blaz'=>{'one'=>'three'}})
      MANIFEST

      catalog.resource(:notify, "blah")['message'].should == 'two'
      catalog.resource(:notify, "blaz")['message'].should == 'three'
    end

    it 'should be able to add edges' do
      rg = compile_to_relationship_graph(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        notify { test: }

        create_resources('foocreateresource', {'blah'=>{'one'=>'two', 'require' => 'Notify[test]'}})
      MANIFEST

      test = rg.vertices.find { |v| v.title == 'test' }
      blah = rg.vertices.find { |v| v.title == 'blah' }
      test.must be
      blah.must be
      rg.path_between(test,blah).should be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        create_resources('foocreateresource', {'blah'=>{}}, {'one' => 'two'})
      MANIFEST

      catalog.resource(:notify, "blah")['message'].should == 'two'
    end
  end

  describe 'when creating classes' do
    it 'should be able to create classes' do
      catalog = compile_to_catalog(<<-MANIFEST)
        class bar($one) {
          notify { test: message => $one }
        }

        create_resources('class', {'bar'=>{'one'=>'two'}})
      MANIFEST

      catalog.resource(:notify, "test")['message'].should == 'two'
      catalog.resource(:class, "bar").should_not be_nil
    end

    it 'should fail to create non-existing classes' do
      expect do
        compile_to_catalog(<<-MANIFEST)
          create_resources('class', {'blah'=>{'one'=>'two'}})
        MANIFEST
      end.to raise_error(Puppet::Error, 'Could not find declared class blah at line 1 on node foonode')
    end

    it 'should be able to add edges' do
      rg = compile_to_relationship_graph(<<-MANIFEST)
        class bar($one) {
          notify { test: message => $one }
        }

        notify { tester: }

        create_resources('class', {'bar'=>{'one'=>'two', 'require' => 'Notify[tester]'}})
      MANIFEST

      test   = rg.vertices.find { |v| v.title == 'test' }
      tester = rg.vertices.find { |v| v.title == 'tester' }
      test.must be
      tester.must be
      rg.path_between(tester,test).should be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog(<<-MANIFEST)
        class bar($one) {
          notify { test: message => $one }
        }

        create_resources('class', {'bar'=>{}}, {'one' => 'two'})
      MANIFEST

      catalog.resource(:notify, "test")['message'].should == 'two'
      catalog.resource(:class, "bar").should_not be_nil
    end

    it 'should fail with a correct error message if the syntax of an imported file is incorrect' do
      expect{
        Puppet[:modulepath] = my_fixture_dir
        compile_to_catalog('include foo')
      }.to raise_error(Puppet::Error, /Syntax error at.*/)
    end
  end
end
