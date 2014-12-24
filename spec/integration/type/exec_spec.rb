#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Type.type(:exec) do
  include PuppetSpec::Files

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:path) { tmpfile('exec_provider') }
  let(:command) { "ruby -e 'File.open(\"#{path}\", \"w\") { |f| f.print \"foo\" }'" }

  before :each do
    catalog.host_config = false
  end

  it "should execute the command" do
    exec = described_class.new :command => command, :path => ENV['PATH']

    catalog.add_resource exec
    catalog.apply

    expect(File.read(path)).to eq('foo')
  end

  it "should not execute the command if onlyif returns non-zero" do
    exec = described_class.new(
      :command => command,
      :onlyif => "ruby -e 'exit 44'",
      :path => ENV['PATH']
    )

    catalog.add_resource exec
    catalog.apply

    expect(Puppet::FileSystem.exist?(path)).to be_falsey
  end

  it "should execute the command if onlyif returns zero" do
    exec = described_class.new(
      :command => command,
      :onlyif => "ruby -e 'exit 0'",
      :path => ENV['PATH']
    )

    catalog.add_resource exec
    catalog.apply

    expect(File.read(path)).to eq('foo')
  end

  it "should execute the command if unless returns non-zero" do
    exec = described_class.new(
      :command => command,
      :unless => "ruby -e 'exit 45'",
      :path => ENV['PATH']
    )

    catalog.add_resource exec
    catalog.apply

    expect(File.read(path)).to eq('foo')
  end

  it "should not execute the command if unless returns zero" do
    exec = described_class.new(
      :command => command,
      :unless => "ruby -e 'exit 0'",
      :path => ENV['PATH']
    )

    catalog.add_resource exec
    catalog.apply

    expect(Puppet::FileSystem.exist?(path)).to be_falsey
  end
end
