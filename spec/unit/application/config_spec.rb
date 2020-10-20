# coding: utf-8
require 'spec_helper'
require 'puppet/application/config'

describe Puppet::Application::Config do
  include PuppetSpec::Files

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  MIXED_UTF8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ𠜎

  let(:app) { Puppet::Application[:config] }

  before :each do
    Puppet[:config] = tmpfile('config')
  end

  def initialize_app(args)
    app.command_line.args = args
    # ensure global defaults are initialized prior to app defaults
    Puppet.initialize_settings(args)
  end

  def read_utf8(path)
    File.read(path, :encoding => 'UTF-8')
  end

  def write_utf8(path, content)
    File.write(path, content, 0, :encoding => 'UTF-8')
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

    {
      %w[certname WWW.EXAMPLE.COM] => /Certificate names must be lower case/,
      %w[log_level all] => /Invalid loglevel all/,
      %w[disable_warnings true] => /Cannot disable unrecognized warning types 'true'/,
      %w[strict on] => /Invalid value 'on' for parameter strict/,
      %w[digest_algorithm rot13] => /Invalid value 'rot13' for parameter digest_algorithm/,
      %w[http_proxy_password a#b] => /Passwords set in the http_proxy_password setting must be valid as part of a URL/,
    }.each_pair do |args, message|
      it "rejects #{args.join(' ')}" do
        initialize_app(['set', *args])

        expect {
          app.run
        }.to exit_with(1)
         .and output(message).to_stderr
      end
    end

    it 'sets unknown settings' do
      initialize_app(['set', 'notarealsetting', 'true'])

      expect {
        app.run
      }.to exit_with(0)

      expect(File.read(Puppet[:config])).to eq("[main]\nnotarealsetting = true\n")
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

  context "when managing UTF-8 values" do
    it "reads a UTF-8 value" do
      write_utf8(Puppet[:config], <<~EOF)
        [main]
        tags=#{MIXED_UTF8}
      EOF

      initialize_app(%w[print tags])

      expect {
        app.run
      }.to exit_with(0)
       .and output("#{MIXED_UTF8}\n").to_stdout
    end

    it "sets a UTF-8 value" do
      initialize_app(['set', 'tags', MIXED_UTF8])

      expect {
        app.run
      }.to exit_with(0)

      expect(read_utf8(Puppet[:config])).to eq(<<~EOF)
        [main]
        tags = #{MIXED_UTF8}
      EOF
    end

    it "deletes a UTF-8 value" do
      initialize_app(%w[delete tags])

      write_utf8(Puppet[:config], <<~EOF)
        [main]
        tags=#{MIXED_UTF8}
      EOF

      expect {
        app.run
      }.to exit_with(0)
       .and output(/Deleted setting from 'main': 'tags=#{MIXED_UTF8}'/).to_stdout

      expect(read_utf8(Puppet[:config])).to eq(<<~EOF)
        [main]
      EOF
    end
  end
end
