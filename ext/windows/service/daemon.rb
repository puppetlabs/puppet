#!/usr/bin/env ruby

require 'fileutils'
require 'win32/daemon'
require 'win32/dir'
require 'win32/process'
require 'win32/eventlog'

class WindowsDaemon < Win32::Daemon
  CREATE_NEW_CONSOLE          = 0x00000010
  EVENTLOG_ERROR_TYPE         = 0x0001
  EVENTLOG_WARNING_TYPE       = 0x0002
  EVENTLOG_INFORMATION_TYPE   = 0x0004

  @run_thread = nil
  @LOG_TO_FILE = false
  LOG_FILE =  File.expand_path(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'puppet', 'var', 'log', 'windows.log'))
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
    basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    # The puppet installer registers a 'Puppet' event source.  For the moment events will be logged with this key, but
    # it may be a good idea to split the Service and Puppet events later so it's easier to read in the windows Event Log.
    #
    # Example code to register an event source;
    # eventlogdll =  File.expand_path(File.join(basedir, 'puppet', 'ext', 'windows', 'eventlog', 'puppetres.dll'))
    # if (File.exists?(eventlogdll))
    #   Win32::EventLog.add_event_source(
    #      'source' => "Application",
    #      'key_name' => "Puppet Agent",
    #      'category_count' => 3,
    #      'event_message_file' => eventlogdll,
    #      'category_message_file' => eventlogdll
    #   )
    # end

    puppet = File.join(basedir, 'bin', 'puppet.bat')
    unless File.exists?(puppet)
      log_err("File not found: '#{puppet}'")
      return
    end
    log_debug("Using '#{puppet}'")

    cmdline_debug = argsv.index('--debug') ? :debug : nil
    @loglevel = parse_log_level(puppet, cmdline_debug)
    log_notice('Service started')

    service = self
    @run_thread = Thread.new do
      begin
        while service.running? do
          runinterval = service.parse_runinterval(puppet)
          if service.state == RUNNING or service.state == IDLE
            service.log_notice("Executing agent with arguments: #{args}")
            pid = Process.create(:command_line => "\"#{puppet}\" agent --onetime #{args}", :creation_flags => CREATE_NEW_CONSOLE).process_id
            service.log_debug("Process created: #{pid}")
          else
            service.log_debug("Service is paused.  Not invoking Puppet agent")
          end

          service.log_debug("Service worker thread waiting for #{runinterval} seconds")
          sleep(runinterval)
          service.log_debug('Service worker thread woken up')
        end
      rescue Exception => e
        service.log_exception(e)
      end
    end
    @run_thread.join

  rescue Exception => e
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
        File.open(LOG_FILE, 'a') { |f| f.puts("#{Time.now} Puppet (#{level}): #{msg}") }
      end

      case level
        when :debug, :info, :notice
          report_windows_event(EVENTLOG_INFORMATION_TYPE,0x01,msg.to_s)
        when :err, :alert, :emerg, :crit
          report_windows_event(EVENTLOG_ERROR_TYPE,0x03,msg.to_s)
        else
          report_windows_event(EVENTLOG_WARNING_TYPE,0x02,msg.to_s)
      end
    end
  end

  def report_windows_event(type,id,message)
    begin
      eventlog = nil
      eventlog = Win32::EventLog.open("Application")
      eventlog.report_event(
        :source      => "Puppet",
        :event_type  => type,   # EVENTLOG_ERROR_TYPE, etc
        :event_id    => id,     # 0x01 or 0x02, 0x03 etc.
        :data        => message # "the message"
      )
    rescue Exception => e
      # Ignore all errors
    ensure
      if (!eventlog.nil?)
        eventlog.close
      end
    end
  end

  def parse_runinterval(puppet_path)
    begin
      runinterval = %x{ "#{puppet_path}" agent --configprint runinterval }.to_i
      if runinterval == 0
        runinterval = 1800
        log_err("Failed to determine runinterval, defaulting to #{runinterval} seconds")
      end
    rescue Exception => e
      log_exception(e)
      runinterval = 1800
    end

    runinterval
  end

  def parse_log_level(puppet_path,cmdline_debug)
    begin
      loglevel = %x{ "#{puppet_path}" agent --configprint log_level}.chomp
      unless loglevel
        loglevel = :notice
        log_err("Failed to determine loglevel, defaulting to #{loglevel}")
      end
    rescue Exception => e
      log_exception(e)
      loglevel = :notice
    end

    LEVELS.index(cmdline_debug ? cmdline_debug : loglevel.to_sym)
  end
end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
