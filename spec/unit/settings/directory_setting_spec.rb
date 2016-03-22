#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/directory_setting'

describe Puppet::Settings::DirectorySetting do
  DirectorySetting = Puppet::Settings::DirectorySetting

  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/somepath")
  end

  describe "when being converted to a resource" do
    before do
      @settings = mock 'settings'
      @dir = Puppet::Settings::DirectorySetting.new(
          :settings => @settings, :desc => "eh", :name => :mydir, :section => "mysect")
      @settings.stubs(:value).with(:mydir).returns @basepath
    end

    it "should return :directory as its type" do
      expect(@dir.type).to eq(:directory)
    end



  end
end

