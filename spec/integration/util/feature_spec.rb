#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/feature'
require 'puppet_spec/files'

describe Puppet::Util::Feature do
  include PuppetSpec::Files

  it "should be able to load features from disk" do
    libdir = tmpfile("feature_lib")
    Dir.mkdir(libdir)

    $LOAD_PATH << libdir

    $features = Puppet::Util::Feature.new("feature_lib")

    Dir.mkdir(File.join(libdir, "feature_lib"))

    File.open(File.join(libdir, "feature_lib", "able_to_load.rb"), "w") do |f|
      f.puts "$features.add(:able_to_load) { true }"
    end

    expect($features).to be_able_to_load
  end
end
