#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/string_setting'

describe Puppet::Settings::StringSetting do
  StringSetting = Puppet::Settings::StringSetting

  before(:each) do
    @test_setting_name = :test_setting 
    @test_setting_default = "my_crazy_default/$var"
    @application_setting = "application/$var"
    @application_defaults = { } 
    Puppet::Settings::REQUIRED_APP_SETTINGS.each do |key|
      @application_defaults[key] = "foo"
    end
    @application_defaults[:run_mode] = :user
    @settings = Puppet::Settings.new
    @application_defaults.each { |k,v| @settings.define_settings :main, k => {:default=>"", :desc => "blah"} }
    @settings.define_settings :main, :var               => {  :default => "interpolate!", 
                                                              :type => :string, 
                                                              :desc => "my var desc" },
                                     @test_setting_name => {  :default => @test_setting_default, 
                                                              :type => :string, 
                                                              :desc => "my test desc" }
    @test_setting = @settings.setting(@test_setting_name)
  end

  describe "#default" do
    describe "with no arguments" do
      it "should return the setting default" do
        expect(@test_setting.default).to eq(@test_setting_default)
      end
      
      it "should be uninterpolated" do
        expect(@test_setting.default).not_to match(/interpolate/)
      end
    end
    
    describe "checking application defaults first" do
      describe "if application defaults set" do
        before(:each) do
          @settings.initialize_app_defaults @application_defaults.merge @test_setting_name => @application_setting
        end
        
        it "should return the application-set default" do
          expect(@test_setting.default(true)).to eq(@application_setting)
        end
        
        it "should be uninterpolated" do
          expect(@test_setting.default(true)).not_to match(/interpolate/)
        end
        
      end
      
      describe "if application defaults not set" do
        it "should return the regular default" do
          expect(@test_setting.default(true)).to eq(@test_setting_default)
        end
        
        it "should be uninterpolated" do
          expect(@test_setting.default(true)).not_to match(/interpolate/)
        end
      end
    end
  end
  
  describe "#value" do
    it "should be interpolated" do
      expect(@test_setting.value).to match(/interpolate/)
    end
  end
end

