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
    # Anything in here needs to happen VERY quickly as this service will not send a SERVICE_STARTED event until this function has completed.  Typically this needs to be less than two seconds
  end

  def service_main(*argv)
    args = argv.join(' ')
    
    @LOG_TO_FILE = (argv.index('--logtofile') ? true : false)
    @loglevel = LEVELS.index(argv.index('--debug') ? :debug : :notice)

    if (@LOG_TO_FILE)
      FileUtils.mkdir_p(File.dirname(LOG_FILE))
    end
    
    puppetpid = -1
    basedir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    puppet = File.join(basedir, 'bin', 'puppet.bat')

    # Puppet itself does register this event source as well, but it may well happen that this service may have different message types some day
    eventlogdll =  File.expand_path(File.join(basedir, 'puppet', 'ext', 'windows', 'eventlog', 'puppetres.dll'))
    if (File.exists?(eventlogdll))
      Win32::EventLog.add_event_source(
         'source' => "Application",
         'key_name' => "Puppet Agent",
         'category_count' => 3,
         'event_message_file' => eventlogdll,
         'category_message_file' => eventlogdll
      )
    end

    # Logging can now occur as all event sinks have been configured.
    log_notice("Starting service: #{args}")    

    while running? do
      return if !running?

      log_notice('Service is running')

      unless File.exists?(puppet)
        log_err("File not found: '#{puppet}'")
        return
      end

      return if !running?
      log_debug("Using '#{puppet}'")
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
      
      if (state == RUNNING || state == IDLE)
        puppetpid = Process.create(:command_line => "\"#{puppet}\" agent --onetime #{args}").process_id
        log_debug("Process created: #{puppetpid}")
      else
        log_debug("Service is not in a state to start Puppet")	  
      end

      log_debug("Service waiting for #{runinterval} seconds")
      sleep(runinterval)
      log_debug('Service woken up')
    end

    # TODO: Check if puppetpid is still running.  If so raise a warning in the eventlog and log. Do I let the Puppet run continue or kill the process?
    # If you kill the process, it will only kill the CMD.EXE, not the child RUBY process.
    # Use Win32::Process.kill(0,puppetpid) to see if it's alive
    
    log_notice('Service stopped')
  rescue Exception => e
    log_exception(e)
  end

  def service_stop
    log_notice('Service stopping')
    Thread.main.wakeup
  end
  
  def service_pause
    # I don't know why it does, but the service state eventually comes out of Paused and goes into Running
    # I suspect this is more of a Ruby Win32Daemon issue than this script.
    #
    # Yep, confirmed:
    # From the Win32 Services Gem; daemon.c
    #   ...Program Files (x86)\Puppet Labs\Puppet Enterprise\sys\ruby\lib\ruby\gems\1.9.1\gems\win32-service-0.7.2-x86-mingw32\ext\win32\daemon.c
    # Line 240: // Set the status of the service.
    # Line 241: SetTheServiceStatus(dwState, NO_ERROR, 0, 0);
    #
    # The preceding switch statement sets the dwState to RUNNING when a SERVICE_INTERROGATE event occurs, which is about every 60 seconds and then tells the SCM that this service is RUNNING
    # This is a fairly old version of the Win32 Daemon. v0.8.2 has been released but it looks like it has the same logic flow (Lines 107 to 132)
    # Raised bug https://github.com/djberg96/win32-service/issues/11

    log_notice('Service pausing. The service will not stay paused and will eventually go back into a running state.')
  end

  def service_resume
    log_notice('Service resuming')
  end
  
  def service_shutdown
    log_notice('Host is shutting down')	
  end

  # Interrogation handler is just for debug.  Can be commented out or removed entirely.
  def service_interrogate
    log_debug('Service is being intertogated')
  end
  
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
          raise_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :info
          raise_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :notice
          raise_windows_event(Win32::EventLog::INFO,0x01,msg.to_s)
        when :err
          raise_windows_event(Win32::EventLog::ERR,0x03,msg.to_s)
        else
          raise_windows_event(Win32::EventLog::WARN,0x02,msg.to_s)
      end      
    end
  end
  
  def raise_windows_event(type,id,message)
    begin
      eventlog = Win32::EventLog.open("Application")
     	eventlog.report_event(
     		:source      => "Puppet Agent",
    		:event_type  => type,   # Win32::EventLog::INFO or WARN, ERROR
    		:event_id    => id,     # 0x01 or 0x02, 0x03 etc.
    		:data        => message # "the message"
    	)
      eventlog.close
    rescue Exception => e
      # Ignore all errors
    end
  end

end

if __FILE__ == $0
  WindowsDaemon.mainloop
end
