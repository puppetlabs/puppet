require 'spec_helper'
require 'puppet/settings/server_list_setting'

describe Puppet::Settings::ServerListSetting do

    it "prints items in the same format as the original list" do
      settings = Puppet::Settings.new
      settings.define_settings(:main, neptune: {type: :server_list, desc: 'list of servers'})
      server_list_setting = settings.setting(:neptune)
      expect(server_list_setting.print("jupiter,mars")).to eq("jupiter,mars")
    end

end