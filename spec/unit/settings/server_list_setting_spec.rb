require 'spec_helper'
require 'puppet/settings/server_list_setting'

describe Puppet::Settings::ServerListSetting do

    it "prints strings as strings" do
      settings = Puppet::Settings.new
      settings.define_settings(:main, neptune: {type: :server_list, desc: 'list of servers'})
      server_list_setting = settings.setting(:neptune)
      expect(server_list_setting.print("jupiter,mars")).to eq("jupiter,mars")
    end

    it "prints arrays as strings" do
      settings = Puppet::Settings.new
      settings.define_settings(:main, neptune: {type: :server_list, desc: 'list of servers'})
      server_list_setting = settings.setting(:neptune)
      expect(server_list_setting.print([["main", 1234],["production", 8140]])).to eq("main:1234,production:8140")
      expect(server_list_setting.print([])).to eq("")
    end

end