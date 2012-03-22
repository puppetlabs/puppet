#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/settings'
require 'puppet/util/settings/directory_setting'

describe Puppet::Util::Settings::DirectorySetting do
  DirectorySetting = Puppet::Util::Settings::DirectorySetting

  include PuppetSpec::Files

  before do
    @basepath = make_absolute("/somepath")
  end

  describe "when being converted to a resource" do
    before do
      @settings = mock 'settings'
      @dir = Puppet::Util::Settings::DirectorySetting.new(
          :settings => @settings, :desc => "eh", :name => :mydir, :section => "mysect")
      @settings.stubs(:value).with(:mydir).returns @basepath
    end

    it "should return :directory as its type" do
      @dir.type.should == :directory
    end



  end
end

