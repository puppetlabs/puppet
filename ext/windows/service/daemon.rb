#!/usr/bin/env ruby

require 'fileutils'
require 'win32/daemon'
require 'win32/dir'
require 'win32/process'
require 'win32/eventlog'

require 'windows/synchronize'
require 'windows/handle'

class WindowsDaemon < Win32::Daemon
  include Windows::Synchronize
  include Windows::Handle
  include Windows::Process

  @LOG_TO_FILE = false
  LOG_FILE =  File.expand_path(File.join(Dir::COMMON_APPDATA, 'PuppetLabs', 'puppet', 'var', 'log', 'windows.log'))
  LEVELS = [:debug, :info, :notice, :err]
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

    log_notice('Service started')

    while running? do
      begin
        runinterval = %x{ "#{puppet}" agent --configprint runinterval }.to_i
        if runinterval == 0
          runinterval = 1800
          log_err("Failed to determine runinterval, defaulting to #{runinterval} seconds")
        end
      rescue Exception => e
        log_exception(e)
        runinterval = 1800
      end

      if state == RUNNING or state == IDLE
        log_notice("Executing agent with arguments: #{args}")
        pid = Process.create(:command_line => "\"#{puppet}\" agent --onetime #{args}", :creation_flags => Process::CREATE_NEW_CONSOLE).process_id
        log_debug("Process created: #{pid}")
      else
        log_debug("Service is paused.  Not invoking Puppet agent")
      end

      log_debug("Service waiting for #{runinterval} seconds")
      sleep(runinterval)
      log_debug('Service woken up')
    end

    log_notice('Service stopped')
  rescue Exception => e
    log_exception(e)
  end

  def service_stop
    log_notice('Service stopping')
    Thread.main.wakeup
  end

  def service_pause
    # The service will not stay in a paused stated, instead it will go back into a running state after a short period of time.  This is an issue in the Win32-Service ruby code
    # Raised bug https://github.com/djberg96/win32-service/issues/11 and is fixed in version 0.8.3.
    # Because the Pause feature is so rarely used, there is no point in creating a workaround until puppet uses 0.8.3.
    log_notice('Service pausing. The service will not stay paused. See Puppet Issue PUP-1471 for more information')
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
        when :debug
          report_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :info
          report_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :notice
          report_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :err
          report_windows_event(Win32::EventLog::ERR,0x03,msg.to_s)
        else
          report_windows_event(Win32::EventLog::WARN,0x02,msg.to_s)
      end
    end
  end

  def report_windows_event(type,id,message)
    begin
      eventlog = nil
      eventlog = Win32::EventLog.open("Application")
      eventlog.report_event(
        :source      => "Puppet",
        :event_type  => type,   # Win32::EventLog::INFO or WARN, ERROR
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
end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
