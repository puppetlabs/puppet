require 'spec_helper'

require 'puppet/util/rdoc'
require 'rdoc/rdoc'

describe Puppet::Util::RDoc do
  describe "when generating RDoc HTML documentation" do
    before :each do
      @rdoc = double('rdoc')
      allow(RDoc::RDoc).to receive(:new).and_return(@rdoc)
    end

    it "should tell RDoc to generate documentation using the Puppet generator" do
      expect(@rdoc).to receive(:document).with(include("--fmt").and(include("puppet")))

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should tell RDoc to be quiet" do
      expect(@rdoc).to receive(:document).with(include("--quiet"))

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should pass charset to RDoc" do
      expect(@rdoc).to receive(:document).with(include("--charset").and(include("utf-8")))

      Puppet::Util::RDoc.rdoc("output", [], "utf-8")
    end

    it "should tell RDoc to use the given outputdir" do
      expect(@rdoc).to receive(:document).with(include("--op").and(include("myoutputdir")))

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/files section" do
      expect(@rdoc).to receive(:document).with(include("--exclude").and(include("/modules/[^/]*/files/.*$")))

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/templates section" do
      expect(@rdoc).to receive(:document).with(include("--exclude").and(include("/modules/[^/]*/templates/.*$")))

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should give all the source directories to RDoc" do
      expect(@rdoc).to receive(:document).with(include("sourcedir"))

      Puppet::Util::RDoc.rdoc("output", ["sourcedir"])
    end
  end
end
