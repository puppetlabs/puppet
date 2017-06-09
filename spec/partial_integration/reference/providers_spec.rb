#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/reference'

reference = Puppet::Util::Reference.reference(:providers)

describe reference do
  it "should exist" do
    expect(reference).not_to be_nil
  end

  it "should be able to be rendered as markdown" do
    reference.to_markdown
  end
end
