#!/usr/bin/env rspec
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

    $features.should be_able_to_load
  end

  # TODO: Make this a spec test or remove it.
  def test_dynamic_loading
    $features = @features
    cleanup { $features = nil }
    # Now create a feature and make sure it loads.
    FileUtils.mkdir_p(@path)
    nope = File.join(@path, "nope.rb")
    File.open(nope, "w") { |f|
      f.puts "$features.add(:nope, :libs => %w{nosuchlib})"
    }
    assert_nothing_raised("Failed to autoload features") do
      assert(! @features.nope?, "'nope' returned true")
    end

    # First make sure "yep?" returns false
    assert_nothing_raised("Missing feature threw an exception") do
      assert(! @features.notyep?, "'notyep' returned true before definition")
    end

    yep = File.join(@path, "yep.rb")
    File.open(yep, "w") { |f|
      f.puts "$features.add(:yep, :libs => %w{puppet})"
    }

    assert(@features.yep?, "false 'yep' is apparently cached or feature could not be loaded")
  end
end
