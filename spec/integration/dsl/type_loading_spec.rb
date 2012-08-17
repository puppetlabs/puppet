require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/modules'
require 'puppet_spec/files'

include PuppetSpec::Compiler
include PuppetSpec::Modules
include PuppetSpec::Files

describe Puppet::DSL do
  before :all do
    @modulebase = File.join(tmpdir("base"), "modules")
    FileUtils.mkdir_p(@modulebase)

    @module = PuppetSpec::Modules.create "module", @modulebase

    Puppet[:modulepath] = @modulebase
  end

  def mk_manifest(file, content)
    name = @module.name + "::" + file.gsub("/", "::").split(".")[0]
    path = File.join(@modulebase, @module.name, "manifests", file)
    FileUtils.mkdir_p(File.split(path)[0])

    File.open(path, "w") { |f| f.print content }
  end

  before :each do
    prepare_compiler
  end

  describe "type loader" do

    it "should load ruby code when referenced from puppet" do
      mk_manifest("foo.rb", <<-MANIFEST)
        hostclass :'module::foo' do; end
      MANIFEST

      compile_to_catalog(<<-MANIFEST)
        include module::foo
      MANIFEST
    end

    it "should load ruby code when referenced from ruby" do
      mk_manifest("bar.rb", <<-MANIFEST)
        hostclass :'module::bar' do; end
      MANIFEST

      compile_ruby_to_catalog(<<-MANIFEST)
        use :'module::bar'
      MANIFEST
    end

    it "should load puppet code when referenced from ruby" do
      mk_manifest("baz.pp", <<-MANIFEST)
        class module::baz {}
      MANIFEST

      compile_ruby_to_catalog(<<-MANIFEST)
        use :'module::bar'
      MANIFEST
    end

  end
end

