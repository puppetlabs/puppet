#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/status/local'

describe Puppet::Indirector::Status::Local do
  it "should set the puppet version" do
    Puppet::Status.indirection.terminus_class = :local
    expect(Puppet::Status.indirection.find('*').version).to eq(Puppet.version)
  end
end
