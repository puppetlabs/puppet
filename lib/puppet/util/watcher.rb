# frozen_string_literal: true

module Puppet::Util::Watcher
  require_relative 'watcher/timer'
  require_relative 'watcher/change_watcher'
  require_relative 'watcher/periodic_watcher'

  module Common
    def self.file_ctime_change_watcher(filename)
      Puppet::Util::Watcher::ChangeWatcher.watch(lambda do
        Puppet::FileSystem.stat(filename).ctime
      rescue Errno::ENOENT, Errno::ENOTDIR
        :absent
      end)
    end
  end
end
