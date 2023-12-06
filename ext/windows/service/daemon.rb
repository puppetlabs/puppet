#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'puppet/util/windows/daemon'

# This file defines utilities for logging to eventlog. While it lives inside
# Puppet, it is completely independent and loads no other parts of Puppet, so we
# can safely require *just* it.
require 'puppet/util/windows/eventlog'

# monkey patches ruby Process to add .create method
require 'puppet/util/windows/monkey_patches/process'

class WindowsDaemon < Puppet::Util::Windows::Daemon
  CREATE_NEW_CONSOLE          = 0x00000010

  @run_thread = nil
  @LOG_TO_FILE = false
  @loglevel = 0
  LOG_FILE =  File.expand_path(File.join(ENV['ALLUSERSPROFILE'], 'PuppetLabs', 'puppet', 'var', 'log', 'windows.log'))
  LEVELS = [:debug, :info, :notice, :warning, :err, :alert, :emerg, :crit]
  LEVELS.each do |level|
    define_method("log_#{level}") do |msg|
      log(msg, level)
    end
  end

  def service_init
  end

  def service_main(*argsv)
    argsv = (argsv << ARGV).flatten.compact
    args = argsv.join(' ')
    @loglevel = LEVELS.index(argsv.index('--debug') ? :debug : :notice)

    @LOG_TO_FILE = (argsv.index('--logtofile') ? true : false)

    if (@LOG_TO_FILE)
      FileUtils.mkdir_p(File.dirname(LOG_FILE))
      args = args.gsub("--logtofile","")
    end

    base_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    load_env(base_dir)

    # The puppet installer registers a 'Puppet' event source.  For the moment events will be logged with this key, but
    # it may be a good idea to split the Service and Puppet events later so it's easier to read in the windows Event Log.
    #
    # Example code to register an event source;
    # eventlogdll =  File.expand_path(File.join(basedir, 'puppet', 'ext', 'windows', 'eventlog', 'puppetres.dll'))
    # if (File.exist?(eventlogdll))
    #   Win32::EventLog.add_event_source(
    #      'source' => "Application",
    #      'key_name' => "Puppet Agent",
    #      'category_count' => 3,
    #      'event_message_file' => eventlogdll,
    #      'category_message_file' => eventlogdll
    #   )
    # end

    puppet = File.join(base_dir, 'puppet', 'bin', 'puppet')
    ruby = File.join(base_dir, 'puppet', 'bin', 'ruby.exe')
    ruby_puppet_cmd = "\"#{ruby}\" \"#{puppet}\""

    unless File.exist?(puppet)
      log_err("File not found: '#{puppet}'")
      return
    end
    log_debug("Using '#{puppet}'")

    cmdline_debug = argsv.index('--debug') ? :debug : nil
    @loglevel = parse_log_level(ruby_puppet_cmd, cmdline_debug)
    log_notice('Service started')

    service = self
    @run_thread = Thread.new do
      begin
        while service.running? do
          runinterval = service.parse_runinterval(ruby_puppet_cmd)

          if service.state == RUNNING or service.state == IDLE
            service.log_notice("Executing agent with arguments: #{args}")
            pid = Process.create(:command_line => "#{ruby_puppet_cmd} agent --onetime #{args}", :creation_flags => CREATE_NEW_CONSOLE).process_id
            service.log_debug("Process created: #{pid}")
          else
            service.log_debug("Service is paused.  Not invoking Puppet agent")
          end

          service.log_debug("Service worker thread waiting for #{runinterval} seconds")
          sleep(runinterval)
          service.log_debug('Service worker thread woken up')
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        service.log_exception(e)
      end
    end
    @run_thread.join

  rescue Exception => e # rubocop:disable Lint/RescueException
    log_exception(e)
  ensure
    log_notice('Service stopped')
  end

  def service_stop
    log_notice('Service stopping / killing worker thread')
    @run_thread.kill if @run_thread
  end

  def service_pause
    log_notice('Service pausing')
  end

  def service_resume
    log_notice('Service resuming')
  end

  def service_shutdown
    log_notice('Host shutting down')
  end

  # Interrogation handler is just for debug.  Can be commented out or removed entirely.
  # def service_interrogate
  #   log_debug('Service is being interrogated')
  # end

  def log_exception(e)
    log_err(e.message)
    log_err(e.backtrace.join("\n"))
  end

  def log(msg, level)
    if LEVELS.index(level) >= @loglevel
      if (@LOG_TO_FILE)
        # without this change its possible that we get Encoding errors trying to write UTF-8 messages in current codepage
        File.open(LOG_FILE, 'a:UTF-8') { |f| f.puts("#{Time.now} Puppet (#{level}): #{msg}") }
      end

      native_type, native_id = Puppet::Util::Windows::EventLog.to_native(level)
      report_windows_event(native_type, native_id, msg.to_s)
    end
  end

  def report_windows_event(type,id,message)
    begin
      eventlog = nil
      eventlog = Puppet::Util::Windows::EventLog.open("Puppet")
      eventlog.report_event(
        :event_type  => type,   # EVENTLOG_ERROR_TYPE, etc
        :event_id    => id,     # 0x01 or 0x02, 0x03 etc.
        :data        => message # "the message"
      )
    rescue Exception # rubocop:disable Lint/RescueException
      # Ignore all errors
    ensure
      if (!eventlog.nil?)
        eventlog.close
      end
    end
  end

  def parse_runinterval(puppet_path)
    begin
      runinterval = %x{ #{puppet_path} config --section agent --log_level notice print runinterval }.to_i
      if runinterval == 0
        runinterval = 1800
        log_err("Failed to determine runinterval, defaulting to #{runinterval} seconds")
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      log_exception(e)
      runinterval = 1800
    end

    runinterval
  end

  def parse_log_level(puppet_path,cmdline_debug)
    begin
      loglevel = %x{ #{puppet_path} config --section agent --log_level notice print log_level }.chomp
      unless loglevel && respond_to?("log_#{loglevel}")
        loglevel = :notice
        log_err("Failed to determine loglevel, defaulting to #{loglevel}")
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      log_exception(e)
      loglevel = :notice
    end

    LEVELS.index(cmdline_debug ? cmdline_debug : loglevel.to_sym)
  end

  private

  def load_env(base_dir)
    begin
      # ENV that uses backward slashes
      ENV['FACTER_env_windows_installdir'] = base_dir.tr('/', '\\')
      ENV['PL_BASEDIR'] = base_dir.tr('/', '\\')
      ENV['PUPPET_DIR'] = File.join(base_dir, 'puppet').tr('/', '\\')
      ENV['OPENSSL_CONF'] = File.join(base_dir, 'puppet', 'ssl', 'openssl.cnf').tr('/', '\\')
      ENV['SSL_CERT_DIR'] = File.join(base_dir, 'puppet', 'ssl', 'certs').tr('/', '\\')
      ENV['SSL_CERT_FILE'] = File.join(base_dir, 'puppet', 'ssl', 'cert.pem').tr('/', '\\')
      ENV['Path'] = [
        File.join(base_dir, 'puppet', 'bin'),
        File.join(base_dir, 'bin'),
      ].join(';').tr('/', '\\') + ';' + ENV['Path']

      # ENV that uses forward slashes
      ENV['RUBYLIB'] = "#{File.join(base_dir, 'puppet','lib')};#{ENV['RUBYLIB']}"
    rescue => e
      log_exception(e)
    end
  end
end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
