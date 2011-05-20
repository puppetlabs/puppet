#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-10-12.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/reports'

describe Puppet::Reports, " when using report types" do
  before do
    Puppet.settings.stubs(:use)
  end

  it "should load report types as modules" do
    Puppet::Reports.report(:store).should be_instance_of(Module)
  end
end
