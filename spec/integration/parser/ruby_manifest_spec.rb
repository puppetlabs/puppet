#! /usr/bin/env ruby
require 'spec_helper'

require 'tempfile'
require 'puppet_spec/files'

describe "Pure ruby manifests" do
  include PuppetSpec::Files

  before do
    @test_dir = tmpdir('ruby_manifest_test')
  end

  def write_file(name, contents)
    path = File.join(@test_dir, name)
    File.open(path, "w") { |f| f.write(contents) }
    path
  end

  def compile(contents)
    Puppet[:code] = contents
    Dir.chdir(@test_dir) do
      Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
    end
  end

  it "should allow classes" do
    write_file('foo.rb', ["hostclass 'one' do notify('one_notify') end",
                          "hostclass 'two' do notify('two_notify') end"].join("\n"))
    catalog = compile("import 'foo'\ninclude one")
    catalog.resource("Notify[one_notify]").should_not be_nil
    catalog.resource("Notify[two_notify]").should be_nil
  end

  it "should allow defines" do
    write_file('foo.rb', 'define "bar", :arg do notify("bar_#{@name}_#{@arg}") end')
    catalog = compile("import 'foo'\nbar { instance: arg => 'xyz' }")
    catalog.resource("Notify[bar_instance_xyz]").should_not be_nil
    catalog.resource("Bar[instance]").should_not be_nil
  end

  it "should allow node declarations" do
    write_file('foo.rb', "node 'mynode' do notify('mynode') end")
    catalog = compile("import 'foo'")
    node_declaration = catalog.resource("Notify[mynode]")
    node_declaration.should_not be_nil
    node_declaration.title.should == 'mynode'
  end

  it "should allow access to the environment" do
    write_file('foo.rb', ["hostclass 'bar' do",
                          "  if environment.is_a? Puppet::Node::Environment",
                          "    notify('success')",
                          "  end",
                          "end"].join("\n"))
    compile("import 'foo'\ninclude bar").resource("Notify[success]").should_not be_nil
  end

  it "should allow creation of resources of built-in types" do
    write_file('foo.rb', "hostclass 'bar' do file 'test_file', :owner => 'root', :mode => '644' end")
    catalog = compile("import 'foo'\ninclude bar")
    file = catalog.resource("File[test_file]")
    file.should be_a(Puppet::Resource)
    file.type.should == 'File'
    file.title.should == 'test_file'
    file.exported.should_not be
    file.virtual.should_not be
    file[:owner].should == 'root'
    file[:mode].should == '644'
    file[:stage].should be_nil # TODO: is this correct behavior?
  end

  it "should allow calling user-defined functions" do
    write_file('foo.rb', "hostclass 'bar' do user_func 'name', :arg => 'xyz' end")
    catalog = compile(['define user_func($arg) { notify {"n_$arg": } }',
                       'import "foo"',
                       'include bar'].join("\n"))
    catalog.resource("Notify[n_xyz]").should_not be_nil
    catalog.resource("User_func[name]").should_not be_nil
  end

  it "should be properly cached for multiple compiles" do
    # Note: we can't test this by calling compile() twice, because
    # that sets Puppet[:code], which clears out all cached
    # environments.
    Puppet[:filetimeout] = 1000
    write_file('foo.rb', "hostclass 'bar' do notify('success') end")
    Puppet[:code] = "import 'foo'\ninclude bar"

    # Compile the catalog and check it
    catalog = Dir.chdir(@test_dir) do
      Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
    end
    catalog.resource("Notify[success]").should_not be_nil

    # Secretly change the file to make it invalid.  This change
    # shouldn't be noticed because the we've set a high
    # Puppet[:filetimeout].
    write_file('foo.rb', "raise 'should not be executed'")

    # Compile the catalog a second time and make sure it's still ok.
    catalog = Dir.chdir(@test_dir) do
      Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
    end
    catalog.resource("Notify[success]").should_not be_nil
  end

  it "should be properly reloaded when stale" do
    Puppet[:filetimeout] = -1 # force stale check to happen all the time
    write_file('foo.rb', "hostclass 'bar' do notify('version1') end")
    catalog = compile("import 'foo'\ninclude bar")
    catalog.resource("Notify[version1]").should_not be_nil
    sleep 1 # so that timestamp will change forcing file reload
    write_file('foo.rb', "hostclass 'bar' do notify('version2') end")
    catalog = compile("import 'foo'\ninclude bar")
    catalog.resource("Notify[version1]").should be_nil
    catalog.resource("Notify[version2]").should_not be_nil
  end
end
