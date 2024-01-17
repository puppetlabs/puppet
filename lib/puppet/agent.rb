# frozen_string_literal: true

require_relative '../puppet/application'
require_relative '../puppet/error'
require_relative '../puppet/util/at_fork'

require 'timeout'

# A general class for triggering a run of another
# class.
class Puppet::Agent
  require_relative 'agent/locker'
  include Puppet::Agent::Locker

  require_relative 'agent/disabler'
  include Puppet::Agent::Disabler

  require_relative '../puppet/util/splayer'
  include Puppet::Util::Splayer

  # Special exception class used to signal an agent run has timed out.
  class RunTimeoutError < Exception # rubocop:disable Lint/InheritException
  end

  attr_reader :client_class, :client, :should_fork

  def initialize(client_class, should_fork = true)
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
      log_disabled_message
      return
    end

    result = nil
    wait_for_lock_deadline = nil
    block_run = Puppet::Application.controlled_run do
      # splay may sleep for awhile when running onetime! If not onetime, then
      # the job scheduler splays (only once) so that agents assign themselves a
      # slot within the splay interval.
      do_splay = client_options.fetch(:splay, Puppet[:splay])
      if do_splay
        splay(do_splay)

        if disabled?
          log_disabled_message
          break
        end
      end

      # waiting for certs may sleep for awhile depending on onetime, waitforcert and maxwaitforcert!
      # this needs to happen before forking so that if we fail to obtain certs and try to exit, then
      # we exit the main process and not the forked child.
      ssl_context = wait_for_certificates(client_options)

      result = run_in_fork(should_fork) do
        with_client(client_options[:transaction_uuid], client_options[:job_id]) do |client|
          client_args = client_options.merge(:pluginsync => Puppet::Configurer.should_pluginsync?)
          begin
            # lock may sleep for awhile depending on waitforlock and maxwaitforlock!
            lock do
              if disabled?
                log_disabled_message
                nil
              else
                # NOTE: Timeout is pretty heinous as the location in which it
                # throws an error is entirely unpredictable, which means that
                # it can interrupt code blocks that perform cleanup or enforce
                # sanity. The only thing a Puppet agent should do after this
                # error is thrown is die with as much dignity as possible.
                Timeout.timeout(Puppet[:runtimeout], RunTimeoutError) do
                  Puppet.override(ssl_context: ssl_context) do
                    client.run(client_args)
                  end
                end
              end
            end
          rescue Puppet::LockError
            now = Time.now.to_i
            wait_for_lock_deadline ||= now + Puppet[:maxwaitforlock]

            if Puppet[:waitforlock] < 1
              Puppet.notice _("Run of %{client_class} already in progress; skipping  (%{lockfile_path} exists)") % { client_class: client_class, lockfile_path: lockfile_path }
              nil
            elsif now >= wait_for_lock_deadline
              Puppet.notice _("Exiting now because the maxwaitforlock timeout has been exceeded.")
              nil
            else
              Puppet.info _("Another puppet instance is already running; --waitforlock flag used, waiting for running instance to finish.")
              Puppet.info _("Will try again in %{time} seconds.") % { time: Puppet[:waitforlock] }
              sleep Puppet[:waitforlock]
              retry
            end
          rescue RunTimeoutError => detail
            Puppet.log_exception(detail, _("Execution of %{client_class} did not complete within %{runtimeout} seconds and was terminated.") %
              { client_class: client_class, runtimeout: Puppet[:runtimeout] })
            nil
          rescue StandardError => detail
            Puppet.log_exception(detail, _("Could not run %{client_class}: %{detail}") % { client_class: client_class, detail: detail })
            nil
          ensure
            Puppet.runtime[:http].close
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
          exit(yield || 1)
        rescue NoMemoryError
          exit(254)
        end
      end
    ensure
      atForkHandler.parent
    end

    exit_code = Process.waitpid2(child_pid)
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

  def wait_for_certificates(options)
    waitforcert = options[:waitforcert] || (Puppet[:onetime] ? 0 : Puppet[:waitforcert])
    sm = Puppet::SSL::StateMachine.new(waitforcert: waitforcert, onetime: Puppet[:onetime])
    sm.ensure_client_certificate
  end

  def log_disabled_message
    Puppet.notice _("Skipping run of %{client_class}; administratively disabled (Reason: '%{disable_message}');\nUse 'puppet agent --enable' to re-enable.") % { client_class: client_class, disable_message: disable_message }
  end
end
