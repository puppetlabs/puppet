#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

require 'puppettest/fileparsing'

provider_class = Puppet::Type.type(:mailalias).provider(:aliases)

describe provider_class do
  include PuppetTest::FileParsing

  before :each do
    @provider = provider_class
  end

  # #1560
  it "should be able to parse the mailalias examples" do
    my_fixtures do |file|
      fakedataparse(file)
    end
  end
end
