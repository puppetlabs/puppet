#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppettest'
require 'puppettest/support/utils'
require 'puppettest/fileparsing'

provider_class = Puppet::Type.type(:mailalias).provider(:aliases)

describe provider_class do
  include PuppetTest
  include PuppetTest::FileParsing

  before :each do
    @provider = provider_class
  end

  # #1560
  it "should be able to parse each example" do
    fakedata("data/providers/mailalias/aliases").each { |file|
      fakedataparse(file)
    }
  end
end
