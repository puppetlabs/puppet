# Monitor a given watcher for changes on a periodic interval.
class Puppet::Util::Watcher::PeriodicWatcher
  # @param watcher [Puppet::Util::Watcher::ChangeWatcher] a watcher for the value to watch
  # @param timer [Puppet::Util::Watcher::Timer] A timer to determin when to
  #   recheck the watcher. If the timout of the timer is negative, then the
  #   watched value is always considered to be changed
  def initialize(watcher, timer)
    @watcher = watcher
    @timer = timer

    @timer.start
  end

  # @return [true, false] If the file has changed since it was last checked.
  def changed?
    return true if always_consider_changed?

    @watcher = examine_watched_info(@watcher)
    @watcher.changed?
  end

  private

  def always_consider_changed?
    @timer.timeout < 0
  end

  def examine_watched_info(known)
    if @timer.expired?
      @timer.start
      known.next_reading
    else
      known
    end
  end
end

