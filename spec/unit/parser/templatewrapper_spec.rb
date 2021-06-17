require 'spec_helper'
require 'puppet/parser/templatewrapper'

describe Puppet::Parser::TemplateWrapper do
  include PuppetSpec::Files

  let(:known_resource_types) { Puppet::Resource::TypeCollection.new("env") }
  let(:scope) do
    compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    allow(compiler.environment).to receive(:known_resource_types).and_return(known_resource_types)
    Puppet::Parser::Scope.new compiler
  end

  let(:tw) { Puppet::Parser::TemplateWrapper.new(scope) }

  it "fails if a template cannot be found" do
    expect(Puppet::Parser::Files).to receive(:find_template).and_return(nil)

    expect { tw.file = "fake_template" }.to raise_error(Puppet::ParseError)
  end

  it "stringifies as template[<filename>] for a file based template" do
    allow(Puppet::Parser::Files).to receive(:find_template).and_return("/tmp/fake_template")
    tw.file = "fake_template"
    expect(tw.to_s).to eql("template[/tmp/fake_template]")
  end

  it "stringifies as template[inline] for a string-based template" do
    expect(tw.to_s).to eql("template[inline]")
  end

  it "reads and evaluates a file-based template" do
    given_a_template_file("fake_template", "template contents")

    tw.file = "fake_template"
    expect(tw.result).to eql("template contents")
  end

  it "provides access to the name of the template via #file" do
    full_file_name = given_a_template_file("fake_template", "<%= file %>")

    tw.file = "fake_template"
    expect(tw.result).to eq(full_file_name)
  end

  it "ignores a leading BOM" do
    full_file_name = given_a_template_file("bom_template", "\uFEFF<%= file %>")

    tw.file = "bom_template"
    expect(tw.result).to eq(full_file_name)
  end

  it "evaluates a given string as a template" do
    expect(tw.result("template contents")).to eql("template contents")
  end

  it "provides the defined classes with #classes" do
    catalog = double('catalog', :classes => ["class1", "class2"])
    expect(scope).to receive(:catalog).and_return(catalog)
    expect(tw.classes).to eq(["class1", "class2"])
  end

  it "provides all the tags with #all_tags" do
    catalog = double('catalog', :tags => ["tag1", "tag2"])
    expect(scope).to receive(:catalog).and_return(catalog)
    expect(tw.all_tags).to eq(["tag1","tag2"])
  end

  it "raises not implemented error" do
    expect {
      tw.tags
    }.to raise_error(NotImplementedError, /Call 'all_tags' instead/)
  end

  it "raises error on access to removed in-scope variables via method calls" do
    scope["in_scope_variable"] = "is good"
    expect { tw.result("<%= in_scope_variable %>") }.to raise_error(/undefined local variable or method `in_scope_variable'/ )
  end

  it "reports that variable is available when it is in scope" do
    scope["in_scope_variable"] = "is good"
    expect(tw.result("<%= has_variable?('in_scope_variable') %>")).to eq("true")
  end

  it "reports that a variable is not available when it is not in scope" do
    expect(tw.result("<%= has_variable?('not_in_scope_variable') %>")).to eq("false")
  end

  it "provides access to in-scope variables via instance variables" do
    scope["one"] = "foo"
    expect(tw.result("<%= @one %>")).to eq("foo")
  end

  %w{! . ; :}.each do |badchar|
    it "translates #{badchar} to _ in instance variables" do
      scope["one#{badchar}"] = "foo"
      expect(tw.result("<%= @one_ %>")).to eq("foo")
    end
  end

  def given_a_template_file(name, contents)
    full_name = tmpfile("template_#{name}")
    File.binwrite(full_name, contents)

    allow(Puppet::Parser::Files).to receive(:find_template).
      with(name, anything()).
      and_return(full_name)

    full_name
  end
end
