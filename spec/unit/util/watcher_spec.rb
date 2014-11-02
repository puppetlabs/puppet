#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/watcher'

describe Puppet::Util::Watcher do
  describe "the common file ctime watcher" do
    FakeStat = Struct.new(:ctime)

    def ctime(time)
      FakeStat.new(time)
    end

    let(:filename) { "fake" }

    def after_reading_the_sequence(initial, *results)
      expectation = Puppet::FileSystem.expects(:stat).with(filename).at_least(1)
      ([initial] + results).each do |result|
        expectation = if result.is_a? Class
                        expectation.raises(result)
                      else
                        expectation.returns(result)
                      end.then
      end

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      results.size.times { watcher = watcher.next_reading }

      watcher
    end

    it "is initially unchanged" do
      expect(after_reading_the_sequence(ctime(20))).to_not be_changed
    end

    it "has not changed if a section of the file path continues to not exist" do
      expect(after_reading_the_sequence(Errno::ENOTDIR, Errno::ENOTDIR)).to_not be_changed
    end

    it "has not changed if the file continues to not exist" do
      expect(after_reading_the_sequence(Errno::ENOENT, Errno::ENOENT)).to_not be_changed
    end

    it "has changed if the file is created" do
      expect(after_reading_the_sequence(Errno::ENOENT, ctime(20))).to be_changed
    end

    it "is marked as changed if the file is deleted" do
      expect(after_reading_the_sequence(ctime(20), Errno::ENOENT)).to be_changed
    end

    it "is marked as changed if the file modified" do
      expect(after_reading_the_sequence(ctime(20), ctime(21))).to be_changed
    end
  end
end
