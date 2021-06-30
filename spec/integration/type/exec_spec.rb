require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Type.type(:exec), unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:path) { tmpfile('exec_provider') }

  before :each do
    catalog.host_config = false
  end

  shared_examples_for 'a valid exec resource' do
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

  context 'when command is a string' do
    let(:command) { "ruby -e 'File.open(\"#{path}\", \"w\") { |f| f.print \"foo\" }'" }

    it_behaves_like 'a valid exec resource'
  end

  context 'when command is an array' do
    let(:command) { ['ruby', '-e', "File.open(\"#{path}\", \"w\") { |f| f.print \"foo\" }"] }

    it_behaves_like 'a valid exec resource'

    context 'when is invalid' do
      let(:command) { [ "ruby -e 'puts 1'" ] }

      it 'logs error' do
        exec = described_class.new :command => command, :path => ENV['PATH']
        catalog.add_resource exec
        logs = catalog.apply.report.logs

        expect(logs[0].message).to eql("Could not find command 'ruby -e 'puts 1''")
      end
    end
  end
end
