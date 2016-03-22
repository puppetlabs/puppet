#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/templatewrapper'

describe Puppet::Parser::TemplateWrapper do
  let(:known_resource_types) { Puppet::Resource::TypeCollection.new("env") }
  let(:scope) do
    compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    compiler.environment.stubs(:known_resource_types).returns known_resource_types
    Puppet::Parser::Scope.new compiler
  end

  let(:tw) { Puppet::Parser::TemplateWrapper.new(scope) }

  it "fails if a template cannot be found" do
    Puppet::Parser::Files.expects(:find_template).returns nil

    expect { tw.file = "fake_template" }.to raise_error(Puppet::ParseError)
  end

  it "stringifies as template[<filename>] for a file based template" do
    Puppet::Parser::Files.stubs(:find_template).returns("/tmp/fake_template")
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

  it "evaluates a given string as a template" do
    expect(tw.result("template contents")).to eql("template contents")
  end

  it "provides the defined classes with #classes" do
    catalog = mock 'catalog', :classes => ["class1", "class2"]
    scope.expects(:catalog).returns( catalog )
    expect(tw.classes).to eq(["class1", "class2"])
  end

  it "provides all the tags with #all_tags" do
    catalog = mock 'catalog', :tags => ["tag1", "tag2"]
    scope.expects(:catalog).returns( catalog )
    expect(tw.all_tags).to eq(["tag1","tag2"])
  end

  it "provides the tags defined in the current scope with #tags" do
    scope.expects(:tags).returns( ["tag1", "tag2"] )
    expect(tw.tags).to eq(["tag1","tag2"])
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
    full_name = "/full/path/to/#{name}"
    Puppet::Parser::Files.stubs(:find_template).
      with(name, anything()).
      returns(full_name)
    Puppet::FileSystem.stubs(:read_preserve_line_endings).with(full_name).returns(contents)

    full_name
  end
end
