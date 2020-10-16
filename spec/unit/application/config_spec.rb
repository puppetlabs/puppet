require 'spec_helper'
require 'puppet/application/config'

describe Puppet::Application::Config do
  include PuppetSpec::Files

  let(:app) { Puppet::Application[:config] }

  before :each do
    Puppet[:config] = tmpfile('config')
  end

  def initialize_app(args)
    app.command_line.args = args
    # ensure global defaults are initialized prior to app defaults
    Puppet.initialize_settings(args)
  end

  context "when printing" do
    it "prints a value" do
      initialize_app(%w[print certname])

      expect {
        app.run
      }.to exit_with(0)
       .and output(a_string_matching(Puppet[:certname])).to_stdout
    end

    it "prints a value from a section" do
      File.write(Puppet[:config], <<~END)
        [main]
        external_nodes=none
        [server]
        external_nodes=exec
      END

      initialize_app(%w[print external_nodes --section server])

      expect {
        app.run
      }.to exit_with(0)
       .and output(a_string_matching('exec')).to_stdout
    end

    it "doesn't require the environment to exist" do
      initialize_app(%w[print certname --environment doesntexist])

      expect {
        app.run
      }.to exit_with(0)
       .and output(a_string_matching(Puppet[:certname])).to_stdout
    end
  end

  context "when setting" do
    it "sets a value in its config file" do
      initialize_app(%w[set certname www.example.com])

      expect {
        app.run
      }.to exit_with(0)

      expect(File.read(Puppet[:config])).to eq("[main]\ncertname = www.example.com\n")
    end

    it "sets a value in the server section" do
      initialize_app(%w[set external_nodes exec --section server])

      expect {
        app.run
      }.to exit_with(0)

      expect(File.read(Puppet[:config])).to eq("[server]\nexternal_nodes = exec\n")
    end
  end

  context "when deleting" do
    it "deletes a value" do
      initialize_app(%w[delete external_nodes])

      File.write(Puppet[:config], <<~END)
        [main]
        external_nodes=none
      END

      expect {
        app.run
      }.to exit_with(0)
       .and output(/Deleted setting from 'main': 'external_nodes=none'/).to_stdout

      expect(File.read(Puppet[:config])).to eq("[main]\n")
    end

    it "warns when deleting a value that isn't set" do
      initialize_app(%w[delete external_nodes])

      File.write(Puppet[:config], "")

      expect {
        app.run
      }.to exit_with(0)
       .and output(a_string_matching("Warning: No setting found in configuration file for section 'main' setting name 'external_nodes'")).to_stderr

      expect(File.read(Puppet[:config])).to eq("")
    end

    it "deletes a value from main" do
      initialize_app(%w[delete external_nodes])

      File.write(Puppet[:config], <<~END)
        [main]
        external_nodes=none
      END

      expect {
        app.run
      }.to exit_with(0)
       .and output(/Deleted setting from 'main': 'external_nodes=none'/).to_stdout

      expect(File.read(Puppet[:config])).to eq("[main]\n")
    end

    it "deletes a value from main a section" do
      initialize_app(%w[delete external_nodes --section server])

      File.write(Puppet[:config], <<~END)
        [main]
        external_nodes=none
        [server]
        external_nodes=exec
      END

      expect {
        app.run
      }.to exit_with(0)
       .and output(/Deleted setting from 'server': 'external_nodes'/).to_stdout

      expect(File.read(Puppet[:config])).to eq("[main]\nexternal_nodes=none\n[server]\n")
    end
  end
end
