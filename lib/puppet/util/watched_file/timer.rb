class Puppet::Util::WatchedFile
  class Timer

    def start(timeout)
      @start_time = now
      @timeout = timeout
    end

    def expired?
      (now - @start_time) >= @timeout
    end

    def now
      Time.now.to_i
    end
  end
end
