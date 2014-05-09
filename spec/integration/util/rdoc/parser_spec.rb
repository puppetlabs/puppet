#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/rdoc'

describe "RDoc::Parser" do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  let(:document_all) { false }
  let(:tmp_dir) { tmpdir('rdoc_parser_tmp') }
  let(:doc_dir) { File.join(tmp_dir, 'doc') }
  let(:manifests_dir) { File.join(tmp_dir, 'manifests') }
  let(:modules_dir) { File.join(tmp_dir, 'modules') }

  let(:modules_and_manifests) do
    {
      :site => [
        File.join(manifests_dir, 'site.pp'),
        <<-EOF
# The test class comment
class test {
  # The virtual resource comment
  @notify { virtual: }
  # The a_notify_resource comment
  notify { a_notify_resource:
    message => "a_notify_resource message"
  }
}

# The includes_another class comment
class includes_another {
  include another
}

# The requires_another class comment
class requires_another {
  require another
}

# node comment
node foo {
  include test
  $a_var = "var_value"
  realize Notify[virtual]
  notify { bar: }
}
        EOF
      ],
      :module_readme => [
        File.join(modules_dir, 'a_module', 'README'),
        <<-EOF
The a_module README docs.
        EOF
      ],
      :module_init => [
        File.join(modules_dir, 'a_module', 'manifests', 'init.pp'),
        <<-EOF
# The a_module class comment
class a_module {}

class another {}
        EOF
      ],
      :module_type => [
        File.join(modules_dir, 'a_module', 'manifests', 'a_type.pp'),
        <<-EOF
# The a_type type comment
define a_module::a_type() {}
        EOF
      ],
      :module_plugin => [
        File.join(modules_dir, 'a_module', 'lib', 'puppet', 'type', 'a_plugin.rb'),
        <<-EOF
# The a_plugin type comment
Puppet::Type.newtype(:a_plugin) do
  @doc = "Not presented"
end
        EOF
      ],
      :module_function => [
        File.join(modules_dir, 'a_module', 'lib', 'puppet', 'parser', 'a_function.rb'),
        <<-EOF
# The a_function function comment
module Puppet::Parser::Functions
  newfunction(:a_function, :type => :rvalue) do
    return
  end
end
        EOF
      ],
      :module_fact => [
        File.join(modules_dir, 'a_module', 'lib', 'facter', 'a_fact.rb'),
        <<-EOF
# The a_fact fact comment
Facter.add("a_fact") do
end
        EOF
      ],
    }
  end

  def write_file(file, content)
    FileUtils.mkdir_p(File.dirname(file))
    File.open(file, 'w') do |f|
      f.puts(content)
    end
  end

  def prepare_manifests_and_modules
    modules_and_manifests.each do |key,array|
      write_file(*array)
    end
  end

  def file_exists_and_matches_content(file, *content_patterns)
    Puppet::FileSystem.exist?(file).should(be_true, "Cannot find #{file}")
    content_patterns.each do |pattern|
      content = File.read(file)
      content.should match(pattern)
    end
  end

  def some_file_exists_with_matching_content(glob, *content_patterns)
    Dir.glob(glob).select do |f|
      contents = File.read(f)
      content_patterns.all? { |p| p.match(contents) }
    end.should_not(be_empty, "Could not match #{content_patterns} in any of the files found in #{glob}")
  end

  around(:each) do |example|
    env = Puppet::Node::Environment.create(:doc_test_env, [modules_dir], manifests_dir)
    Puppet.override({:environments => Puppet::Environments::Static.new(env), :current_environment => env}) do
      example.run
    end
  end

  before :each do
    prepare_manifests_and_modules
    Puppet.settings[:document_all] = document_all
    Puppet.settings[:modulepath] = modules_dir
    Puppet::Util::RDoc.rdoc(doc_dir, [modules_dir, manifests_dir])
  end

  module RdocTesters
    def has_module_rdoc(module_name, *other_test_patterns)
      file_exists_and_matches_content(module_path(module_name), /Module:? +#{module_name}/i, *other_test_patterns)
    end

    def has_node_rdoc(module_name, node_name, *other_test_patterns)
      file_exists_and_matches_content(node_path(module_name, node_name), /#{node_name}/, /node comment/, *other_test_patterns)
    end

    def has_defined_type(module_name, type_name)
      file_exists_and_matches_content(module_path(module_name), /#{type_name}.*?\(\s*\)/m, "The .*?#{type_name}.*? type comment")
    end

    def has_class_rdoc(module_name, class_name, *other_test_patterns)
      file_exists_and_matches_content(class_path(module_name, class_name), /#{class_name}.*? class comment/, *other_test_patterns)
    end

    def has_plugin_rdoc(module_name, type, name)
      file_exists_and_matches_content(plugin_path(module_name, type, name), /The .*?#{name}.*?\s*#{type} comment/m, /Type.*?#{type}/m)
    end
  end

  shared_examples_for :an_rdoc_site do
    it "documents the __site__ module" do
      has_module_rdoc("__site__")
    end

    it "documents the __site__::test class" do
      has_class_rdoc("__site__", "test")
    end

    it "documents the __site__::foo node" do
      has_node_rdoc("__site__", "foo")
    end

    it "documents the a_module module" do
      has_module_rdoc("a_module", /The .*?a_module.*? .*?README.*?docs/m)
    end

    it "documents the a_module::a_module class" do
      has_class_rdoc("a_module", "a_module")
    end

    it "documents the a_module::a_type defined type" do
      has_defined_type("a_module", "a_type")
    end

    it "documents the a_module::a_plugin type" do
      has_plugin_rdoc("a_module", :type, 'a_plugin')
    end

    it "documents the a_module::a_function function" do
      has_plugin_rdoc("a_module", :function, 'a_function')
    end

    it "documents the a_module::a_fact fact" do
      has_plugin_rdoc("a_module", :fact, 'a_fact')
    end

    it "documents included classes" do
      has_class_rdoc("__site__", "includes_another", /Included.*?another/m)
    end
  end

  shared_examples_for :an_rdoc1_site do
    it "documents required classes" do
      has_class_rdoc("__site__", "requires_another", /Required Classes.*?another/m)
    end

    it "documents realized resources" do
      has_node_rdoc("__site__", "foo", /Realized Resources.*?Notify\[virtual\]/m)
    end

    it "documents global variables" do
      has_node_rdoc("__site__", "foo", /Global Variables.*?a_var.*?=.*?var_value/m)
    end

    describe "when document_all is true" do
      let(:document_all) { true }

      it "documents virtual resource declarations" do
        has_class_rdoc("__site__", "test", /Resources.*?Notify\[virtual\]/m, /The virtual resource comment/)
      end

      it "documents resources" do
        has_class_rdoc("__site__", "test", /Resources.*?Notify\[a_notify_resource\]/m, /message => "a_notify_resource message"/, /The a_notify_resource comment/)
      end
    end
  end

  describe "rdoc1 support", :if => Puppet.features.rdoc1? do
    def module_path(module_name); "#{doc_dir}/classes/#{module_name}.html" end
    def node_path(module_name, node_name);  "#{doc_dir}/nodes/**/*.html" end
    def class_path(module_name, class_name); "#{doc_dir}/classes/#{module_name}/#{class_name}.html" end
    def plugin_path(module_name, type, name); "#{doc_dir}/plugins/#{name}.html" end

    include RdocTesters

    def has_node_rdoc(module_name, node_name, *other_test_patterns)
      some_file_exists_with_matching_content(node_path(module_name, node_name), /#{node_name}/, /node comment/, *other_test_patterns)
    end

    it_behaves_like :an_rdoc_site
    it_behaves_like :an_rdoc1_site

    it "references nodes and classes in the __site__ module" do
      file_exists_and_matches_content("#{doc_dir}/classes/__site__.html", /Node.*__site__::foo/, /Class.*__site__::test/)
    end

    it "references functions, facts, and type plugins in the a_module module" do
      file_exists_and_matches_content("#{doc_dir}/classes/a_module.html", /a_function/, /a_fact/, /a_plugin/, /Class.*a_module::a_module/)
    end
  end

  describe "rdoc2 support", :if => !Puppet.features.rdoc1? do
    def module_path(module_name); "#{doc_dir}/#{module_name}.html" end
    def node_path(module_name, node_name);  "#{doc_dir}/#{module_name}/__nodes__/#{node_name}.html" end
    def class_path(module_name, class_name); "#{doc_dir}/#{module_name}/#{class_name}.html" end
    def plugin_path(module_name, type, name); "#{doc_dir}/#{module_name}/__#{type}s__.html" end

    include RdocTesters

    it_behaves_like :an_rdoc_site
  end
end
