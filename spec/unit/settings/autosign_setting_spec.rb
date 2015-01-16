require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/autosign_setting'
require 'puppet/type/file'

describe Puppet::Settings::AutosignSetting do
  let(:settings) do
    s = stub('settings')
    s.stubs(:[]).with(:mkusers).returns true
    s.stubs(:[]).with(:user).returns 'puppet'
    s.stubs(:[]).with(:group).returns 'puppet'
    s.stubs(:[]).with(:manage_internal_file_permissions).returns true
    s
  end

  let(:setting) { described_class.new(:name => 'autosign', :section => 'section', :settings => settings, :desc => "test") }

  it "is of type :file" do
    expect(setting.type).to eq :file
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

  describe "setting additional setting values" do
    it "can set the file mode" do
      setting.mode = '0664'
      expect(setting.mode).to eq '0664'
    end

    it "can set the file owner" do
      setting.owner = 'service'
      expect(setting.owner).to eq 'puppet'
    end

    it "can set the file group" do
      setting.group = 'service'
      expect(setting.group).to eq 'puppet'
    end
  end

  describe "converting the setting to a resource" do
    it "converts the file path to a file resource" do
      path = File.expand_path('/path/to/autosign.conf')
      settings.stubs(:value).with('autosign', nil, false).returns(path)
      Puppet::FileSystem.stubs(:exist?).with(path).returns true
      Puppet.stubs(:features).returns(stub(:root? => true, :microsoft_windows? => false))

      setting.mode = '0664'
      setting.owner = 'service'
      setting.group = 'service'

      resource = setting.to_resource

      expect(resource.title).to eq path
      expect(resource[:ensure]).to eq :file
      expect(resource[:mode]).to eq '664'
      expect(resource[:owner]).to eq 'puppet'
      expect(resource[:group]).to eq 'puppet'
    end

    it "returns nil when the setting is a boolean" do
      settings.stubs(:value).with('autosign', nil, false).returns 'true'

      setting.mode = '0664'
      setting.owner = 'service'
      setting.group = 'service'

      expect(setting.to_resource).to be_nil
    end
  end
end
