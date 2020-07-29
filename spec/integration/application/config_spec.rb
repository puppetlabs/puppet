# coding: utf-8
require 'spec_helper'
require 'puppet/application/config'

#describe "puppet config" do
describe Puppet::Face[:config, '0.0.1'] do
  include PuppetSpec::Files

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  MIXED_UTF8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ𠜎

  let(:tmp_config) { tmpfile('puppet.conf') }
  let(:config) { Puppet::Application[:config] }

  def read_utf8(path)
    File.read(tmp_config, :encoding => 'UTF-8')
  end

  def write_utf8(path, content)
    File.write(tmp_config, content, 0, :encoding => 'UTF-8')
  end

  it "reads a UTF-8 value" do
    write_utf8(tmp_config, <<~EOF)
      [main]
      tags=#{MIXED_UTF8}
    EOF

    Puppet.initialize_settings(['--config', tmp_config])
    config.command_line.args = ['print', 'tags' ]

    expect {
      config.run
    }.to exit_with(0)
     .and output("#{MIXED_UTF8}\n").to_stdout
  end

  it "sets a UTF-8 value" do
    Puppet.initialize_settings(['--config', tmp_config])
    config.command_line.args = ['set', 'tags', MIXED_UTF8 ]

    expect {
      config.run
    }.to exit_with(0)

    expect(read_utf8(tmp_config)).to eq(<<~EOF)
      [main]
      tags = #{MIXED_UTF8}
    EOF
  end

  it "deletes a key" do
    write_utf8(tmp_config, <<~EOF)
      [main]
      tags=#{MIXED_UTF8}
    EOF

    Puppet.initialize_settings(['--config', tmp_config])
    config.command_line.args = ['delete', 'tags']

    expect {
      config.run
    }.to exit_with(0)
     .and output(/Deleted setting from 'main': 'tags=#{MIXED_UTF8}'/).to_stdout

    expect(read_utf8(tmp_config)).to eq(<<~EOF)
      [main]
    EOF
  end
end
