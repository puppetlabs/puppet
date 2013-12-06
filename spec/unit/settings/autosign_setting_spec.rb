require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/autosign_setting'

describe Puppet::Settings::AutosignSetting do
  let(:setting) { described_class.new(:settings => mock('settings'), :desc => "test") }

  it "is of type :autosign" do
    expect(setting.type).to eq :autosign
  end

  describe "when munging the setting" do
    it "passes boolean values through" do
      expect(setting.munge(true)).to eq true
      expect(setting.munge(false)).to eq false
    end

    it "converts nil to false" do
      expect(setting.munge(nil)).to eq false
    end

    it "munges string 'true' to boolean true" do
      expect(setting.munge('true')).to eq true
    end

    it "munges string 'false' to boolean false" do
      expect(setting.munge('false')).to eq false
    end

    it "passes absolute paths through" do
      path = File.expand_path('/path/to/autosign.conf')
      expect(setting.munge(path)).to eq path
    end

    it "fails if given anything else" do
      cases = [1.0, 'sometimes', 'relative/autosign.conf']

      cases.each do |invalid|
        expect {
          setting.munge(invalid)
        }.to raise_error Puppet::Settings::ValidationError, /Invalid autosign value/
      end
    end
  end
end
