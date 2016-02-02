require 'puppet/application'
require 'puppet/error'

# A general class for triggering a run of another
# class.
class Puppet::Agent
  require 'puppet/agent/locker'
  include Puppet::Agent::Locker

  require 'puppet/agent/disabler'
  include Puppet::Agent::Disabler

  require 'puppet/util/splayer'
  include Puppet::Util::Splayer

  attr_reader :client_class, :client, :should_fork

  def initialize(client_class, should_fork=true)
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
            client_args = client_options.merge(:pluginsync => Puppet::Configurer.should_pluginsync?)
            lock { client.run(client_args) }
          rescue Puppet::LockError
            Puppet.notice "Run of #{client_class} already in progress; skipping  (#{lockfile_path} exists)"
            return
          rescue StandardError => detail
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
    rescue StandardError => detail
      Puppet.log_exception(detail, "Could not create instance of #{client_class}: #{detail}")
      return
    end
    yield @client
  ensure
    @client = nil
  end
end
