#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/rdoc'

describe "RDoc::Parser", :unless => Puppet.features.microsoft_windows? do
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
    expect(Puppet::FileSystem.exist?(file)).to(be_truthy, "Cannot find #{file}")
    content_patterns.each do |pattern|
      content = File.read(file)
      expect(content).to match(pattern)
    end
  end

  def some_file_exists_with_matching_content(glob, *content_patterns)
    expect(Dir.glob(glob).select do |f|
      contents = File.read(f)
      content_patterns.all? { |p| p.match(contents) }
    end).not_to(be_empty, "Could not match #{content_patterns} in any of the files found in #{glob}")
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
    def has_plugin_rdoc(module_name, type, name)
      file_exists_and_matches_content(plugin_path(module_name, type, name), /The .*?#{name}.*?\s*#{type} comment/m, /Type.*?#{type}/m)
    end
  end

  shared_examples_for :an_rdoc_site do
    # PUP-3274 / PUP-3638 not sure if this should be kept or not - it is now broken
#    it "documents the __site__ module" do
#      has_module_rdoc("__site__")
#    end

    # PUP-3274 / PUP-3638 not sure if this should be kept or not - it is now broken
#    it "documents the a_module module" do
#      has_module_rdoc("a_module", /The .*?a_module.*? .*?README.*?docs/m)
#    end

    it "documents the a_module::a_plugin type" do
      has_plugin_rdoc("a_module", :type, 'a_plugin')
    end

    it "documents the a_module::a_function function" do
      has_plugin_rdoc("a_module", :function, 'a_function')
    end

    it "documents the a_module::a_fact fact" do
      has_plugin_rdoc("a_module", :fact, 'a_fact')
    end
  end

  describe "rdoc2 support" do
    def module_path(module_name); "#{doc_dir}/#{module_name}.html" end
    def plugin_path(module_name, type, name); "#{doc_dir}/#{module_name}/__#{type}s__.html" end

    include RdocTesters

    it_behaves_like :an_rdoc_site
  end
end
