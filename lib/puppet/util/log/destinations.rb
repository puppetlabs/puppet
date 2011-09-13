Puppet::Util::Log.newdesttype :syslog do
  def self.suitable?(obj)
    Puppet.features.syslog?
  end

  def close
    Syslog.close
  end

  def initialize
    Syslog.close if Syslog.opened?
    name = Puppet[:name]
    name = "puppet-#{name}" unless name =~ /puppet/

    options = Syslog::LOG_PID | Syslog::LOG_NDELAY

    # XXX This should really be configurable.
    str = Puppet[:syslogfacility]
    begin
      facility = Syslog.const_get("LOG_#{str.upcase}")
    rescue NameError
      raise Puppet::Error, "Invalid syslog facility #{str}"
    end

    @syslog = Syslog.open(name, options, facility)
  end

  def handle(msg)
    # XXX Syslog currently has a bug that makes it so you
    # cannot log a message with a '%' in it.  So, we get rid
    # of them.
    if msg.source == "Puppet"
      @syslog.send(msg.level, msg.to_s.gsub("%", '%%'))
    else
      @syslog.send(msg.level, "(%s) %s" % [msg.source.to_s.gsub("%", ""),
          msg.to_s.gsub("%", '%%')
        ]
      )
    end
  end
end

Puppet::Util::Log.newdesttype :file do
  def self.match?(obj)
    Puppet::Util.absolute_path?(obj)
  end

  def close
    if defined?(@file)
      @file.close
      @file = nil
    end
  end

  def flush
    @file.flush if defined?(@file)
  end

  attr_accessor :autoflush

  def initialize(path)
    @name = path
    # first make sure the directory exists
    # We can't just use 'Config.use' here, because they've
    # specified a "special" destination.
    unless FileTest.exist?(File.dirname(path))
      Puppet.recmkdir(File.dirname(path))
      Puppet.info "Creating log directory #{File.dirname(path)}"
    end

    # create the log file, if it doesn't already exist
    file = File.open(path, File::WRONLY|File::CREAT|File::APPEND)

    @file = file

    @autoflush = Puppet[:autoflush]
  end

  def handle(msg)
    @file.puts("#{msg.time} #{msg.source} (#{msg.level}): #{msg}")

    @file.flush if @autoflush
  end
end

Puppet::Util::Log.newdesttype :console do


  RED     = {:console => "[0;31m", :html => "FFA0A0"}
  GREEN   = {:console => "[0;32m", :html => "00CD00"}
  YELLOW  = {:console => "[0;33m", :html => "FFFF60"}
  BLUE    = {:console => "[0;34m", :html => "80A0FF"}
  PURPLE  = {:console => "[0;35m", :html => "FFA500"}
  CYAN    = {:console => "[0;36m", :html => "40FFFF"}
  WHITE   = {:console => "[0;37m", :html => "FFFFFF"}
  HRED    = {:console => "[1;31m", :html => "FFA0A0"}
  HGREEN  = {:console => "[1;32m", :html => "00CD00"}
  HYELLOW = {:console => "[1;33m", :html => "FFFF60"}
  HBLUE   = {:console => "[1;34m", :html => "80A0FF"}
  HPURPLE = {:console => "[1;35m", :html => "FFA500"}
  HCYAN   = {:console => "[1;36m", :html => "40FFFF"}
  HWHITE  = {:console => "[1;37m", :html => "FFFFFF"}
  RESET   = {:console => "[0m",    :html => ""      }

  Colormap = {
    :debug => WHITE,
    :info => GREEN,
    :notice => CYAN,
    :warning => YELLOW,
    :err => HPURPLE,
    :alert => RED,
    :emerg => HRED,
    :crit => HRED
  }

  def colorize(level, str)
    case Puppet[:color]
    when true, :ansi, "ansi", "yes"; console_color(level, str)
    when :html, "html"; html_color(level, str)
    else
      str
    end
  end

  def console_color(level, str)
    Colormap[level][:console] + str + RESET[:console]
  end

  def html_color(level, str)
    %{<span style="color: %s">%s</span>} % [Colormap[level][:html], str]
  end

  def initialize
    # Flush output immediately.
    $stdout.sync = true
  end

  def handle(msg)
    if msg.source == "Puppet"
      puts colorize(msg.level, "#{msg.level}: #{msg}")
    else
      puts colorize(msg.level, "#{msg.level}: #{msg.source}: #{msg}")
    end
  end
end

Puppet::Util::Log.newdesttype :host do
  def initialize(host)
    Puppet.info "Treating #{host} as a hostname"
    args = {}
    if host =~ /:(\d+)/
      args[:Port] = $1
      args[:Server] = host.sub(/:\d+/, '')
    else
      args[:Server] = host
    end

    @name = host

    @driver = Puppet::Network::Client::LogClient.new(args)
  end

  def handle(msg)
    unless msg.is_a?(String) or msg.remote
      @hostname ||= Facter["hostname"].value
      unless defined?(@domain)
        @domain = Facter["domain"].value
        @hostname += ".#{@domain}" if @domain
      end
      if msg.source =~ /^\//
        msg.source = @hostname + ":#{msg.source}"
      elsif msg.source == "Puppet"
        msg.source = @hostname + " #{msg.source}"
      else
        msg.source = @hostname + " #{msg.source}"
      end
      begin
        #puts "would have sent #{msg}"
        #puts "would have sent %s" %
        #    CGI.escape(YAML.dump(msg))
        begin
          tmp = CGI.escape(YAML.dump(msg))
        rescue => detail
          puts "Could not dump: #{detail}"
          return
        end
        # Add the hostname to the source
        @driver.addlog(tmp)
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err detail
        Puppet::Util::Log.close(self)
      end
    end
  end
end

# Log to a transaction report.
Puppet::Util::Log.newdesttype :report do
  attr_reader :report

  match "Puppet::Transaction::Report"

  def initialize(report)
    @report = report
  end

  def handle(msg)
    @report << msg
  end
end

# Log to an array, just for testing.
module Puppet::Test
  class LogCollector
    def initialize(logs)
      @logs = logs
    end

    def <<(value)
      @logs << value
    end
  end
end

Puppet::Util::Log.newdesttype :array do
  match "Puppet::Test::LogCollector"

  def initialize(messages)
    @messages = messages
  end

  def handle(msg)
    @messages << msg
  end
end

