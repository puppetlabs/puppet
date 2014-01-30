require 'puppet/agent'
require 'puppet/configurer'
require 'puppet/indirector'

# A basic class for running the agent.  Used by
# `puppet kick` to kick off agents remotely.
class Puppet::Run
  extend Puppet::Indirector
  indirects :run, :terminus_class => :local

  attr_reader :status, :background, :options

  def agent
    # Forking disabled for "puppet kick" runs
    Puppet::Agent.new(Puppet::Configurer, false)
  end

  def background?
    background
  end

  def initialize(options = {})
    if options.include?(:background)
      @background = options[:background]
      options.delete(:background)
    end

    valid_options = [:tags, :ignoreschedules, :pluginsync]
    options.each do |key, value|
      raise ArgumentError, "Run does not accept #{key}" unless valid_options.include?(key)
    end

    @options = options
  end

  def initialize_from_hash(hash)
    @options = {}

    hash['options'].each do |key, value|
      @options[key.to_sym] = value
    end

    @background = hash['background']
    @status = hash['status']
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

  def self.from_hash(hash)
    obj = allocate
    obj.initialize_from_hash(hash)
    obj
  end

  def self.from_data_hash(data)
    if data['options']
      return from_hash(data)
    end

    options = { :pluginsync => Puppet[:pluginsync] }

    data.each do |key, value|
      options[key.to_sym] = value
    end

    new(options)
  end

  def self.from_pson(hash)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(hash)
  end

  def to_data_hash
    {
      :options => @options,
      :background => @background,
      :status => @status
    }
  end
end
