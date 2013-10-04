require 'spec_helper'

require 'puppet/util/watcher'

describe Puppet::Util::Watcher::PeriodicWatcher do
  let(:enabled_timeout) { 1 }
  let(:disabled_timeout) { -1 }
  let(:a_value) { 15 }
  let(:a_different_value) { 16 }

  let(:unused_watcher) { mock('unused watcher') }
  let(:unchanged_watcher) { a_watcher_reporting(a_value) }
  let(:changed_watcher) { a_watcher_reporting(a_value, a_different_value) }

  it 'reads only the initial change state when the timeout has not yet expired' do
    watcher = Puppet::Util::Watcher::PeriodicWatcher.new(unchanged_watcher, an_unexpired_timer(enabled_timeout))

    expect(watcher).to_not be_changed
  end

  it 'reads enough values to determine change when the timeout has expired' do
    watcher = Puppet::Util::Watcher::PeriodicWatcher.new(changed_watcher, an_expired_timer(enabled_timeout))

    expect(watcher).to be_changed
  end

  it 'is always marked as changed when the timeout is disabled' do
    watcher = Puppet::Util::Watcher::PeriodicWatcher.new(unused_watcher, an_expired_timer(disabled_timeout))

    expect(watcher).to be_changed
  end

  def a_watcher_reporting(*observed_values)
    Puppet::Util::Watcher::ChangeWatcher.watch(proc do
      observed_values.shift or raise "No more observed values to report!"
    end)
  end

  def an_expired_timer(timeout)
    a_time_that_reports_expired_as(true, timeout)
  end

  def an_unexpired_timer(timeout)
    a_time_that_reports_expired_as(false, timeout)
  end

  def a_time_that_reports_expired_as(expired, timeout)
    timer = Puppet::Util::Watcher::Timer.new(timeout)
    timer.stubs(:expired?).returns(expired)
    timer
  end
end
