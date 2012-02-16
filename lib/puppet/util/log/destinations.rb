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
  require 'fileutils'

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
      FileUtils.mkdir_p(File.dirname(path), :mode => 0755)
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

module ColoredOutput
  RED        = {:console => "\e[0;31m", :html => "color: #FFA0A0"     }
  GREEN      = {:console => "\e[0;32m", :html => "color: #00CD00"     }
  YELLOW     = {:console => "\e[0;33m", :html => "color: #FFFF60"     }
  BLUE       = {:console => "\e[0;34m", :html => "color: #80A0FF"     }
  PURPLE     = {:console => "\e[0;35m", :html => "color: #FFA500"     }
  CYAN       = {:console => "\e[0;36m", :html => "color: #40FFFF"     }
  WHITE      = {:console => "\e[0;37m", :html => "color: #FFFFFF"     }
  HRED       = {:console => "\e[1;31m", :html => "color: #FFA0A0"     }
  HGREEN     = {:console => "\e[1;32m", :html => "color: #00CD00"     }
  HYELLOW    = {:console => "\e[1;33m", :html => "color: #FFFF60"     }
  HBLUE      = {:console => "\e[1;34m", :html => "color: #80A0FF"     }
  HPURPLE    = {:console => "\e[1;35m", :html => "color: #FFA500"     }
  HCYAN      = {:console => "\e[1;36m", :html => "color: #40FFFF"     }
  HWHITE     = {:console => "\e[1;37m", :html => "color: #FFFFFF"     }
  BG_RED     = {:console => "\e[0;41m", :html => "background: #FFA0A0"}
  BG_GREEN   = {:console => "\e[0;42m", :html => "background: #00CD00"}
  BG_YELLOW  = {:console => "\e[0;43m", :html => "background: #FFFF60"}
  BG_BLUE    = {:console => "\e[0;44m", :html => "background: #80A0FF"}
  BG_PURPLE  = {:console => "\e[0;45m", :html => "background: #FFA500"}
  BG_CYAN    = {:console => "\e[0;46m", :html => "background: #40FFFF"}
  BG_WHITE   = {:console => "\e[0;47m", :html => "background: #FFFFFF"}
  BG_HRED    = {:console => "\e[1;41m", :html => "background: #FFA0A0"}
  BG_HGREEN  = {:console => "\e[1;42m", :html => "background: #00CD00"}
  BG_HYELLOW = {:console => "\e[1;43m", :html => "background: #FFFF60"}
  BG_HBLUE   = {:console => "\e[1;44m", :html => "background: #80A0FF"}
  BG_HPURPLE = {:console => "\e[1;45m", :html => "background: #FFA500"}
  BG_HCYAN   = {:console => "\e[1;46m", :html => "background: #40FFFF"}
  BG_HWHITE  = {:console => "\e[1;47m", :html => "background: #FFFFFF"}
  RESET      = {:console => "\e[0m",    :html => ""                   }

  Colormap = {
    :debug => WHITE,
    :info => GREEN,
    :notice => CYAN,
    :warning => YELLOW,
    :err => HPURPLE,
    :alert => RED,
    :emerg => HRED,
    :crit => HRED,

    :red        => RED,
    :green      => GREEN,
    :yellow     => YELLOW,
    :blue       => BLUE,
    :purple     => PURPLE,
    :cyan       => CYAN,
    :white      => WHITE,
    :hred       => HRED,
    :hgreen     => HGREEN,
    :hyellow    => HYELLOW,
    :hblue      => HBLUE,
    :hpurple    => HPURPLE,
    :hcyan      => HCYAN,
    :hwhite     => HWHITE,
    :bg_red     => BG_RED,
    :bg_green   => BG_GREEN,
    :bg_yellow  => BG_YELLOW,
    :bg_blue    => BG_BLUE,
    :bg_purple  => BG_PURPLE,
    :bg_cyan    => BG_CYAN,
    :bg_white   => BG_WHITE,
    :bg_hred    => BG_HRED,
    :bg_hgreen  => BG_HGREEN,
    :bg_hyellow => BG_HYELLOW,
    :bg_hblue   => BG_HBLUE,
    :bg_hpurple => BG_HPURPLE,
    :bg_hcyan   => BG_HCYAN,
    :bg_hwhite  => BG_HWHITE,
    :reset      => { :console => "\e[m", :html => "" }
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
    Colormap[level][:console] +
    str.gsub(RESET[:console], Colormap[level][:console]) +
    RESET[:console]
  end

  def html_color(level, str)
    %{<span style="%s">%s</span>} % [Colormap[level][:html], str]
  end

  def initialize
    # Flush output immediately.
    $stderr.sync = true
    $stdout.sync = true
  end
end

Puppet::Util::Log.newdesttype :console do
  include ColoredOutput

  def handle(msg)
    if msg.source == "Puppet"
      puts colorize(msg.level, "#{msg.level}: #{msg}")
    else
      puts colorize(msg.level, "#{msg.level}: #{msg.source}: #{msg}")
    end
  end
end

Puppet::Util::Log.newdesttype :new_console do
  include ColoredOutput

  def handle(msg)
    case msg.level
    when :err
        $stderr.puts colorize(:hred, "Error: #{msg}")
    when :warning
      $stderr.puts colorize(:hred, "Warning: #{msg}")
    else
      $stdout.puts msg
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
      if Puppet::Util.absolute_path?(msg.source)
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

