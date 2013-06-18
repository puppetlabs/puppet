#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/watched_file'

describe Puppet::Util::WatchedFile do

  class WatchedFile_MockTimer
    def initialize; @expired = false; end
    def start(_); end
    def expired=(exp); @expired = exp; end
    def expired?; @expired; end
  end

  let(:mock_time) { Time.at(2005).to_i }

  let(:timer) { WatchedFile_MockTimer.new }

  subject { described_class.new('/some/file', 15, timer) }

  describe 'with an initially non-existent file' do

    before { subject.ctime = :absent }

    it "isn't marked as changed if the file continues to not exist" do
      subject.stubs(:file_ctime).returns(:absent)
      timer.expired = true
      subject.should_not be_changed
    end

    it "is marked as changed if the file is created" do
      subject.stubs(:file_ctime).returns mock_time
      timer.expired = true
      subject.should be_changed
    end
  end

  describe 'with an initially present file' do
    before { subject.ctime = mock_time }

    describe "and the file didn't change" do
      before { subject.stubs(:file_ctime).returns mock_time }

      it "should not be changed" do
        timer.expired = true
        subject.should_not be_changed
      end
    end

    describe "and the file was changed" do
      before { subject.stubs(:file_ctime).returns mock_time + 60 }

      it "doesn't mark a file as changed until the file timeout expires" do
        timer.expired = false
        subject.should_not be_changed
      end

      it "marks the file as changed after the file timeout expires" do
        timer.expired = true
        subject.should be_changed
      end
    end

    describe 'and the file was removed' do
      before { subject.stubs(:file_ctime).returns :absent }
      it "marks the file as changed" do
        timer.expired = true
        subject.should be_changed
      end
    end
  end

  describe 'with a disabled file timeout time period' do
    subject { described_class.new('/some/file', -1, timer) }
    it 'is always marked as changed' do
      timer.expired = false
      subject.should be_changed
      subject.should be_changed
    end
  end
end
