
class MultiThreadedBehaviourRunner < Spec::Runner::BehaviourRunner
  def initialize(options)
    super
    # configure these
    @thread_count = 4
    @thread_wait = 0
  end

  def run_behaviours(behaviours)
    @threads = []
    q = Queue.new
    behaviours.each { |b| q << b}
    @thread_count.times do
      @threads << Thread.new(q) do |queue|
        while not queue.empty?
          behaviour = queue.pop
          behaviour.run(@options.reporter, @options.dry_run, @options.reverse)
        end
      end
      sleep @thread_wait
    end
    @threads.each {|t| t.join}
  end
end
