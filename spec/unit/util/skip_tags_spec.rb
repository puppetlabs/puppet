# coding: utf-8
require 'spec_helper'

require 'puppet/util/skip_tags'

describe Puppet::Util::SkipTags do
  let(:tagger) { Puppet::Util::SkipTags.new([]) }

  it "should add qualified classes as single tags" do
    tagger.tag("one::two::three")
    expect(tagger.tags).to include("one::two::three")
    expect(tagger.tags).not_to include("one", "two", "three")
  end
end
