#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/reports'

describe Puppet::Reports, " when using report types" do
  before do
    Puppet.settings.stubs(:use)
  end

  it "should load report types as modules" do
    expect(Puppet::Reports.report(:store)).to be_instance_of(Module)
  end
end
