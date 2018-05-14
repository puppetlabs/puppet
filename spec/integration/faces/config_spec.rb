#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:config, '0.0.1'] do
  include PuppetSpec::Files

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  MIXED_UTF8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ𠜎
  let (:tmp_environment_path) { tmpdir('envpath') }
  let (:tmp_config) { tmpfile('puppet.conf') }

  def load_settings(path)
    test_settings = Puppet::Settings.new

    test_settings.define_settings(:main,
      :config => {
        :type => :file,
        :default => path,
        :desc => '',
      },
      :environmentpath => {
        :default => tmp_environment_path,
        :desc => '',
      },
      :basemodulepath => {
        :default => '',
        :desc => '',
      },
      # definition required to use the value
      :rando_key => {
        :default => '',
        :desc => ''
      },
      MIXED_UTF8.to_sym => {
        :default => '',
        :desc => ''
      },
    )

    test_settings.initialize_global_settings
    test_settings
  end

  before :each do
    File.open(tmp_config, 'w', :encoding => 'UTF-8') do |file|
      file.puts <<-EOF
[main]
rando_key=foobar
#{MIXED_UTF8}=foobar
      EOF
    end
  end

  context 'when getting / setting UTF8 values' do

    let(:config) { described_class }

    def render(action, result)
      config.get_action(action).when_rendering(:console).call(result)
    end

    before :each do
      subject.stubs(:report_section_and_environment)
    end

    # key must be a defined setting
    ['rando_key', MIXED_UTF8].each do |key|
      it "can change '#{key}' keyed ASCII value to a UTF-8 value and read it back" do
        value = "value#{key.reverse}value"

        # needed for the subject.set to write to correct file
        Puppet.settings.stubs(:which_configuration_file).returns(tmp_config)
        subject.set(key, value)

        # make sure subject.print looks at the newly modified settings
        test_settings = load_settings(tmp_config)
        # instead of the default Puppet.settings (implementation detail)
        Puppet.stubs(:settings).returns(test_settings)

        result = subject.print()
        expect(render(:print, result)).to match(/^#{key} = #{value}$/)
        result = subject.print(key, :section => 'main')
        expect(render(:print, result)).to eq("#{value}\n")
      end
    end
  end
end
