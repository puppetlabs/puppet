#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:pip3)

describe provider_class do

  it "should inherit most things from pip provider" do
    expect(provider_class < Puppet::Type.type(:package).provider(:pip))
  end

  it "should use pip3 command" do
    expect(provider_class.cmd).to eq(["pip3"])
  end

end
