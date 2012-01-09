require 'sync'
require 'puppet/external/event-loop'
require 'puppet/application'

# A general class for triggering a run of another
# class.
class Puppet::Agent
  require 'puppet/agent/locker'
  include Puppet::Agent::Locker

  require 'puppet/agent/disabler'
  include Puppet::Agent::Disabler

  attr_reader :client_class, :client, :splayed

  # Just so we can specify that we are "the" instance.
  def initialize(client_class)
    @splayed = false

    @client_class = client_class
  end

  def lockfile_path
    client_class.lockfile_path
  end

  def needing_restart?
    Puppet::Application.restart_requested?
  end

  # Perform a run with our client.
  def run(*args)
    if running?
      Puppet.notice "Run of #{client_class} already in progress; skipping"
      return
    end
    if disabled?
      Puppet.notice "Skipping run of #{client_class}; administratively disabled: #{disable_message}"
      return
    end
    result = nil
    block_run = Puppet::Application.controlled_run do
      splay
      with_client do |client|
        begin
          sync.synchronize { lock { result = client.run(*args) } }
        rescue SystemExit,NoMemoryError
          raise
        rescue Exception => detail
          puts detail.backtrace if Puppet[:trace]
          Puppet.err "Could not run #{client_class}: #{detail}"
        end
      end
      true
    end
    Puppet.notice "Shutdown/restart in progress; skipping run" unless block_run
    result
  end

  def stopping?
    Puppet::Application.stop_requested?
  end

  # Have we splayed already?
  def splayed?
    splayed
  end

  # Sleep when splay is enabled; else just return.
  def splay
    return unless Puppet[:splay]
    return if splayed?

    time = rand(Integer(Puppet[:splaylimit]) + 1)
    Puppet.info "Sleeping for #{time} seconds (splay is enabled)"
    sleep(time)
    @splayed = true
  end

  # Start listening for events.  We're pretty much just listening for
  # timer events here.
  def start
    # Create our timer.  Puppet will handle observing it and such.
    timer = EventLoop::Timer.new(:interval => Puppet[:runinterval], :tolerance => 1, :start? => true) do
      run
    end

    # Run once before we start following the timer
    timer.sound_alarm
  end

  def sync
    @sync ||= Sync.new
  end

  private

  # Create and yield a client instance, keeping a reference
  # to it during the yield.
  def with_client
    begin
      @client = client_class.new
    rescue SystemExit,NoMemoryError
      raise
    rescue Exception => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err "Could not create instance of #{client_class}: #{detail}"
      return
    end
    yield @client
  ensure
    @client = nil
  end
end
