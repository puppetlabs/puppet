module Puppet::Util::Watcher
  require 'puppet/util/watcher/timer'
  require 'puppet/util/watcher/change_watcher'
  require 'puppet/util/watcher/periodic_watcher'

  module Common
    def self.file_ctime_change_watcher(filename)
      Puppet::Util::Watcher::ChangeWatcher.watch(lambda do
        begin
          Puppet::FileSystem.stat(filename).ctime
        rescue Errno::ENOENT, Errno::ENOTDIR
          :absent
        end
      end)
    end
  end
end
