require 'puppet/application'
require 'puppet/error'
require 'puppet/util/at_fork'

require 'timeout'

# A general class for triggering a run of another
# class.
class Puppet::Agent
  require 'puppet/agent/locker'
  include Puppet::Agent::Locker

  require 'puppet/agent/disabler'
  include Puppet::Agent::Disabler

  require 'puppet/util/splayer'
  include Puppet::Util::Splayer

  # Special exception class used to signal an agent run has timed out.
  class RunTimeoutError < Exception
  end

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
      Puppet.notice _("Skipping run of %{client_class}; administratively disabled (Reason: '%{disable_message}');\nUse 'puppet agent --enable' to re-enable.") % { client_class: client_class, disable_message: disable_message }
      return
    end

    result = nil
    block_run = Puppet::Application.controlled_run do
      splay client_options.fetch :splay, Puppet[:splay]
      result = run_in_fork(should_fork) do
        with_client(client_options[:transaction_uuid], client_options[:job_id]) do |client|
          client_args = client_options.merge(:pluginsync => Puppet::Configurer.should_pluginsync?)
          begin
            lock do
              # NOTE: Timeout is pretty heinous as the location in which it
              # throws an error is entirely unpredictable, which means that
              # it can interrupt code blocks that perform cleanup or enforce
              # sanity. The only thing a Puppet agent should do after this
              # error is thrown is die with as much dignity as possible.
              Timeout.timeout(Puppet[:runtimeout], RunTimeoutError) do
                client.run(client_args)
              end
            end
          rescue Puppet::LockError
            Puppet.notice _("Run of %{client_class} already in progress; skipping  (%{lockfile_path} exists)") % { client_class: client_class, lockfile_path: lockfile_path }
            return
          rescue RunTimeoutError => detail
            Puppet.log_exception(detail, _("Execution of %{client_class} did not complete within %{runtimeout} seconds and was terminated.") %
              {client_class: client_class,
              runtimeout: Puppet[:runtimeout]})
            return 1
          rescue StandardError => detail
            Puppet.log_exception(detail, _("Could not run %{client_class}: %{detail}") % { client_class: client_class, detail: detail })
            1
          end
        end
      end
      true
    end
    Puppet.notice _("Shutdown/restart in progress (%{status}); skipping run") % { status: Puppet::Application.run_status.inspect } unless block_run
    result
  end

  def stopping?
    Puppet::Application.stop_requested?
  end

  def run_in_fork(forking = true)
    return yield unless forking or Puppet.features.windows?

    atForkHandler = Puppet::Util::AtFork.get_handler

    atForkHandler.prepare

    begin
      child_pid = Kernel.fork do
        atForkHandler.child
        $0 = _("puppet agent: applying configuration")
        begin
          exit(yield)
        rescue SystemExit
          exit(-1)
        rescue NoMemoryError
          exit(-2)
        end
      end
    ensure
      atForkHandler.parent
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
  def with_client(transaction_uuid, job_id = nil)
    begin
      @client = client_class.new(transaction_uuid, job_id)
    rescue StandardError => detail
      Puppet.log_exception(detail, _("Could not create instance of %{client_class}: %{detail}") % { client_class: client_class, detail: detail })
      return
    end
    yield @client
  ensure
    @client = nil
  end
end
