#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/package'

describe Puppet::Util::Package, " versioncmp" do

  it "should be able to be used as a module function" do
    expect(Puppet::Util::Package).to respond_to(:versioncmp)
  end

  it "should be able to sort a long set of various unordered versions" do
    ary = %w{ 1.1.6 2.3 1.1a 3.0 1.5 1 2.4 1.1-4 2.3.1 1.2 2.3.0 1.1-3 2.4b 2.4 2.40.2 2.3a.1 3.1 0002 1.1-5 1.1.a 1.06}

    newary = ary.sort { |a, b| Puppet::Util::Package.versioncmp(a,b) }

    expect(newary).to eq(["0002", "1", "1.06", "1.1-3", "1.1-4", "1.1-5", "1.1.6", "1.1.a", "1.1a", "1.2", "1.5", "2.3", "2.3.0", "2.3.1", "2.3a.1", "2.4", "2.4", "2.4b", "2.40.2", "3.0", "3.1"])
  end

end
