require 'puppet/agent'
require 'puppet/configurer'
require 'puppet/indirector'

# A basic class for running the agent.  Used by
# puppetrun to kick off agents remotely.
class Puppet::Run
  extend Puppet::Indirector
  indirects :run, :terminus_class => :local

  attr_reader :status, :background, :options

  def agent
    Puppet::Agent.new(Puppet::Configurer)
  end

  def background?
    background
  end

  def initialize(options = {})
    if options.include?(:background)
      @background = options[:background]
      options.delete(:background)
    end

    valid_options = [:tags, :ignoreschedules]
    options.each do |key, value|
      raise ArgumentError, "Run does not accept #{key}" unless valid_options.include?(key)
    end

    @options = options
  end

  def log_run
    msg = ""
    msg += "triggered run" % if options[:tags]
      msg += " with tags #{options[:tags].inspect}"
    end

    msg += " ignoring schedules" if options[:ignoreschedules]

    Puppet.notice msg
  end

  def run
    if agent.running?
      @status = "running"
      return self
    end

    log_run

    if background?
      Thread.new { agent.run(options) }
    else
      agent.run(options)
    end

    @status = "success"

    self
  end

  def self.from_pson( pson )
    options = {}
    pson.each do |key, value|
      options[key.to_sym] = value
    end

    new(options)
  end

  def to_pson
    @options.merge(:background => @background).to_pson
  end
end
