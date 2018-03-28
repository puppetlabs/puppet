require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'

describe 'function for dynamically creating resources' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  before :each do
    node      = Puppet::Node.new("floppy", :environment => 'production')
    @compiler = Puppet::Parser::Compiler.new(node)
    @scope    = Puppet::Parser::Scope.new(@compiler)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
    Puppet::Parser::Functions.function(:create_resources)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function(:create_resources)).to eq("function_create_resources")
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

  context 'when being called from a manifest in a file' do
    let(:dir) do
      dir_containing('manifests', {
              'site.pp' => <<-EOF
                # comment here to make the call be on a particular
                # source line (3)
                create_resources('notify', {
                  'a'  => { 'message'=>'message a'},
                  'b'  => { 'message'=>'message b'},
                  }
                )
              EOF
          }
      )
    end

    it 'file and line information where call originates is written to all resources created in one call' do
      node = Puppet::Node.new('test')
      file = File.join(dir, 'site.pp')
      Puppet[:manifest] = file
      catalog = Puppet::Parser::Compiler.compile(node).filter { |r| r.virtual? }

      expect(catalog.resource(:notify, 'a').file).to eq(file)
      expect(catalog.resource(:notify, 'a').line).to eq(3)
      expect(catalog.resource(:notify, 'b').file).to eq(file)
      expect(catalog.resource(:notify, 'b').line).to eq(3)
    end

  end
  describe 'when creating native types' do
    it 'empty hash should not cause resources to be added' do
      noop_catalog = compile_to_catalog("create_resources('file', {})")
      empty_catalog = compile_to_catalog("")
      expect(noop_catalog.resources.size).to eq(empty_catalog.resources.size)
    end

    it 'should be able to add' do
      catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}})")
      expect(catalog.resource(:file, "/etc/foo")['ensure']).to eq('present')
    end

    it 'should pick up and pass on file and line information' do
      # mock location as the compile_to_catalog sets Puppet[:code} which does not
      # have file/line support.
      Puppet::Pops::PuppetStack.expects(:top_of_stack).once.returns(['test.pp', 1234])
      catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}})")
      r = catalog.resource(:file, "/etc/foo")
      expect(r.file).to eq('test.pp')
      expect(r.line).to eq(1234)
    end

    it 'should be able to add virtual resources' do
      catalog = compile_to_catalog("create_resources('@file', {'/etc/foo'=>{'ensure'=>'present'}})\nrealize(File['/etc/foo'])")
      expect(catalog.resource(:file, "/etc/foo")['ensure']).to eq('present')
    end

    it 'unrealized exported resources should not be added' do
      # a compiled catalog is normally filtered on virtual resources
      # here the compilation is performed unfiltered to be able to find the exported resource
      # it is then asserted that the exported resource is also virtual (and therefore filtered out by a real compilation).
      catalog = compile_to_catalog_unfiltered("create_resources('@@file', {'/etc/foo'=>{'ensure'=>'present'}})")
      expect(catalog.resource(:file, "/etc/foo").exported).to eq(true)
      expect(catalog.resource(:file, "/etc/foo").virtual).to eq(true)
    end

    it 'should be able to add exported resources' do
      catalog = compile_to_catalog("create_resources('@@file', {'/etc/foo'=>{'ensure'=>'present'}}) realize(File['/etc/foo'])")
      expect(catalog.resource(:file, "/etc/foo")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/etc/foo").exported).to eq(true)
    end

    it 'should accept multiple resources' do
      catalog = compile_to_catalog("create_resources('notify', {'foo'=>{'message'=>'one'}, 'bar'=>{'message'=>'two'}})")
      expect(catalog.resource(:notify, "foo")['message']).to eq('one')
      expect(catalog.resource(:notify, "bar")['message']).to eq('two')
    end

    it 'should fail to add non-existing resource type' do
      expect do
        @scope.function_create_resources(['create-resource-foo', { 'foo' => {} }])
      end.to raise_error(/Unknown resource type: 'create-resource-foo'/)
    end

    it 'should be able to add edges' do
      rg = compile_to_relationship_graph("notify { test: }\n create_resources('notify', {'foo'=>{'require'=>'Notify[test]'}})")
      test  = rg.vertices.find { |v| v.title == 'test' }
      foo   = rg.vertices.find { |v| v.title == 'foo' }
      expect(test).to be
      expect(foo).to be
      expect(rg.path_between(test,foo)).to be
    end

    it 'should filter out undefined edges as they cause errors' do
      rg = compile_to_relationship_graph("notify { test: }\n create_resources('notify', {'foo'=>{'require'=>undef}})")
      test  = rg.vertices.find { |v| v.title == 'test' }
      foo   = rg.vertices.find { |v| v.title == 'foo' }
      expect(test).to be
      expect(foo).to be
      expect(rg.path_between(foo,nil)).to_not be
    end

    it 'should filter out undefined edges in an array as they cause errors' do
      rg = compile_to_relationship_graph("notify { test: }\n create_resources('notify', {'foo'=>{'require'=>[undef]}})")
      test  = rg.vertices.find { |v| v.title == 'test' }
      foo   = rg.vertices.find { |v| v.title == 'foo' }
      expect(test).to be
      expect(foo).to be
      expect(rg.path_between(foo,nil)).to_not be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog("create_resources('file', {'/etc/foo'=>{'ensure'=>'present'}, '/etc/baz'=>{'group'=>'food'}}, {'group' => 'bar'})")
      expect(catalog.resource(:file, "/etc/foo")['group']).to eq('bar')
      expect(catalog.resource(:file, "/etc/baz")['group']).to eq('food')
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
      expect(catalog.resource(:notify, "blah")['message']).to eq('two')
    end

    it 'should fail if defines are missing params' do
      expect {
        compile_to_catalog(<<-MANIFEST)
          define foocreateresource($one) {
            notify { $name: message => $one }
          }

          create_resources('foocreateresource', {'blah'=>{}})
        MANIFEST
      }.to raise_error(Puppet::Error, /Foocreateresource\[blah\]: expects a value for parameter 'one'/)
    end

    it 'should accept undef as explicit value when parameter has no default value' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foocreateresource($one) {
            notify { $name: message => "aaa${one}bbb" }
          }

          create_resources('foocreateresource', {'blah'=>{ one => undef}})
        MANIFEST
      expect(catalog.resource(:notify, "blah")['message']).to eq('aaabbb')
    end

    it 'should use default value expression if given value is undef' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foocreateresource($one = 'xx') {
            notify { $name: message => "aaa${one}bbb" }
          }

          create_resources('foocreateresource', {'blah'=>{ one => undef}})
        MANIFEST
      expect(catalog.resource(:notify, "blah")['message']).to eq('aaaxxbbb')
    end

    it 'should be able to add multiple defines' do
      catalog = compile_to_catalog(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        create_resources('foocreateresource', {'blah'=>{'one'=>'two'}, 'blaz'=>{'one'=>'three'}})
      MANIFEST

      expect(catalog.resource(:notify, "blah")['message']).to eq('two')
      expect(catalog.resource(:notify, "blaz")['message']).to eq('three')
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
      expect(test).to be
      expect(blah).to be
      expect(rg.path_between(test,blah)).to be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog(<<-MANIFEST)
        define foocreateresource($one) {
          notify { $name: message => $one }
        }

        create_resources('foocreateresource', {'blah'=>{}}, {'one' => 'two'})
      MANIFEST

      expect(catalog.resource(:notify, "blah")['message']).to eq('two')
    end
  end

  describe 'when creating classes' do
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

    it 'should be able to create classes' do
      catalog = compile_to_catalog(<<-MANIFEST)
        class bar($one) {
          notify { test: message => $one }
        }

        create_resources('class', {'bar'=>{'one'=>'two'}})
      MANIFEST

      expect(catalog.resource(:notify, "test")['message']).to eq('two')
      expect(catalog.resource(:class, "bar")).not_to be_nil
    end

    [:off, :warning].each do | strictness |
      it "should warn if strict = #{strictness} and class is exported" do
        Puppet[:strict] = strictness
        collect_notices('class test{} create_resources("@@class", {test => {}})')
        expect(warnings).to include(/Classes are not virtualizable/)
      end
    end

    it 'should error if strict = error and class is exported' do
      Puppet[:strict] = :error
      expect{
        compile_to_catalog('class test{} create_resources("@@class", {test => {}})')
      }.to raise_error(/Classes are not virtualizable/)
    end

    [:off, :warning].each do | strictness |
      it "should warn if strict = #{strictness} and class is virtual" do
        Puppet[:strict] = strictness
        collect_notices('class test{} create_resources("@class", {test => {}})')
        expect(warnings).to include(/Classes are not virtualizable/)
      end
    end

    it 'should error if strict = error and class is virtual' do
      Puppet[:strict] = :error
      expect{
        compile_to_catalog('class test{} create_resources("@class", {test => {}})')
      }.to raise_error(/Classes are not virtualizable/)
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
      expect(test).to be
      expect(tester).to be
      expect(rg.path_between(tester,test)).to be
    end

    it 'should account for default values' do
      catalog = compile_to_catalog(<<-MANIFEST)
        class bar($one) {
          notify { test: message => $one }
        }

        create_resources('class', {'bar'=>{}}, {'one' => 'two'})
      MANIFEST

      expect(catalog.resource(:notify, "test")['message']).to eq('two')
      expect(catalog.resource(:class, "bar")).not_to be_nil
    end

    it 'should fail with a correct error message if the syntax of an imported file is incorrect' do
      expect{
        Puppet[:modulepath] = my_fixture_dir
        compile_to_catalog('include foo')
      }.to raise_error(Puppet::Error, /Syntax error at.*/)
    end

    it 'is not available when --tasks is on' do
      Puppet[:tasks] = true
      expect do
        compile_to_catalog(<<-MANIFEST)
          create_resources('class', {'bar'=>{}}, {'one' => 'two'})
        MANIFEST
      end.to raise_error(Puppet::ParseError, /is only available when compiling a catalog/)
    end
  end

  def collect_notices(code)
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      compile_to_catalog(code)
    end
  end

end
