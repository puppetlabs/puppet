require 'spec_helper'

require 'puppet/util/watcher'

describe Puppet::Util::Watcher do
  describe "the common file ctime watcher" do
    FakeStat = Struct.new(:ctime)

    def ctime(time)
      FakeStat.new(time)
    end

    let(:filename) { "fake" }

    it "is initially unchanged" do
      expect(Puppet::FileSystem).to receive(:stat).with(filename).and_return(ctime(20)).at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)

      expect(watcher).to_not be_changed
    end

    it "has not changed if a section of the file path continues to not exist" do
      expect(Puppet::FileSystem).to receive(:stat).with(filename).and_raise(Errno::ENOTDIR).at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      watcher = watcher.next_reading

      expect(watcher).to_not be_changed
    end

    it "has not changed if the file continues to not exist" do
      expect(Puppet::FileSystem).to receive(:stat).with(filename).and_raise(Errno::ENOENT).at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      watcher = watcher.next_reading

      expect(watcher).to_not be_changed
    end

    it "has changed if the file is created" do
      times_stat_called = 0
      expect(Puppet::FileSystem).to receive(:stat).with(filename) do
        times_stat_called += 1
        raise Errno::ENOENT if times_stat_called == 1
        ctime(20)
      end.at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      watcher = watcher.next_reading

      expect(watcher).to be_changed
    end

    it "is marked as changed if the file is deleted" do
      times_stat_called = 0
      expect(Puppet::FileSystem).to receive(:stat).with(filename) do
        times_stat_called += 1
        raise Errno::ENOENT if times_stat_called > 1
        ctime(20)
      end.at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      watcher = watcher.next_reading

      expect(watcher).to be_changed
    end

    it "is marked as changed if the file modified" do
      times_stat_called = 0
      expect(Puppet::FileSystem).to receive(:stat).with(filename) do
        times_stat_called += 1
        if times_stat_called == 1
          ctime(20)
        else
          ctime(21)
        end
      end.at_least(:once)

      watcher = Puppet::Util::Watcher::Common.file_ctime_change_watcher(filename)
      watcher = watcher.next_reading

      expect(watcher).to be_changed
    end
  end
end
