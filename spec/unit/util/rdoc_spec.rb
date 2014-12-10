#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/rdoc'
require 'rdoc/rdoc'

describe Puppet::Util::RDoc do
  describe "when generating RDoc HTML documentation" do
    before :each do
      @rdoc = stub_everything 'rdoc'
      RDoc::RDoc.stubs(:new).returns(@rdoc)
    end

    it "should tell RDoc to generate documentation using the Puppet generator" do
      @rdoc.expects(:document).with { |args| args.include?("--fmt") and args.include?("puppet") }

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should tell RDoc to be quiet" do
      @rdoc.expects(:document).with { |args| args.include?("--quiet") }

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should pass charset to RDoc" do
      @rdoc.expects(:document).with { |args| args.include?("--charset") and args.include?("utf-8") }

      Puppet::Util::RDoc.rdoc("output", [], "utf-8")
    end

    it "should tell RDoc to use the given outputdir" do
      @rdoc.expects(:document).with { |args| args.include?("--op") and args.include?("myoutputdir") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/files section" do
      @rdoc.expects(:document).with { |args| args.include?("--exclude") and args.include?("/modules/[^/]*/files/.*$") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/templates section" do
      @rdoc.expects(:document).with { |args| args.include?("--exclude") and args.include?("/modules/[^/]*/templates/.*$") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should give all the source directories to RDoc" do
      @rdoc.expects(:document).with { |args| args.include?("sourcedir") }

      Puppet::Util::RDoc.rdoc("output", ["sourcedir"])
    end
  end
end
