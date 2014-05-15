require 'puppet/application'

# A general class for triggering a run of another
# class.
class Puppet::Agent
  require 'puppet/agent/locker'
  include Puppet::Agent::Locker

  require 'puppet/agent/disabler'
  include Puppet::Agent::Disabler

  attr_reader :client_class, :client, :splayed, :should_fork

  def initialize(client_class, should_fork=true)
    @splayed = false

    @should_fork = can_fork? && should_fork
    @client_class = client_class
  end

  def can_fork?
    Puppet.features.posix? && RUBY_PLATFORM != 'java'
  end

  def needing_restart?
    Puppet::Application.restart_requested?
  end

  # Perform a run with our client.
  def run(client_options = {})
    if running?
      Puppet.notice "Run of #{client_class} already in progress; skipping  (#{lockfile_path} exists)"
      return
    end
    if disabled?
      Puppet.notice "Skipping run of #{client_class}; administratively disabled (Reason: '#{disable_message}');\nUse 'puppet agent --enable' to re-enable."
      return
    end

    result = nil
    block_run = Puppet::Application.controlled_run do
      splay client_options.fetch :splay, Puppet[:splay]
      result = run_in_fork(should_fork) do
        with_client do |client|
          begin
            client_args = client_options.merge(:pluginsync => Puppet[:pluginsync])
            lock { client.run(client_args) }
          rescue SystemExit,NoMemoryError
            raise
          rescue Exception => detail
            Puppet.log_exception(detail, "Could not run #{client_class}: #{detail}")
          end
        end
      end
      true
    end
    Puppet.notice "Shutdown/restart in progress (#{Puppet::Application.run_status.inspect}); skipping run" unless block_run
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
  def splay(do_splay = Puppet[:splay])
    return unless do_splay
    return if splayed?

    time = rand(Puppet[:splaylimit] + 1)
    Puppet.info "Sleeping for #{time} seconds (splay is enabled)"
    sleep(time)
    @splayed = true
  end

  def run_in_fork(forking = true)
    return yield unless forking or Puppet.features.windows?

    child_pid = Kernel.fork do
      $0 = "puppet agent: applying configuration"
      begin
        exit(yield)
      rescue SystemExit
        exit(-1)
      rescue NoMemoryError
        exit(-2)
      end
    end
    exit_code = Process.waitpid2(child_pid)
    case exit_code[1].exitstatus
    when -1
      raise SystemExit
    when -2
      raise NoMemoryError
    end
    exit_code[1].exitstatus
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
      Puppet.log_exception(detail, "Could not create instance of #{client_class}: #{detail}")
      return
    end
    yield @client
  ensure
    @client = nil
  end
end
