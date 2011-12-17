require 'puppet/indirector'
require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/data'

class Puppet::Util::Instrumentation::Listener
  include Puppet::Util
  include Puppet::Util::Warnings
  extend Puppet::Indirector

  indirects :instrumentation_listener, :terminus_class => :local

  attr_reader :pattern, :listener
  attr_accessor :enabled

  def initialize(listener, pattern = nil, enabled = false)
    @pattern = pattern.is_a?(Symbol) ? pattern.to_s : pattern
    raise "Listener isn't a correct listener (it doesn't provide the notify method)" unless listener.respond_to?(:notify)
    @listener = listener
    @enabled = enabled
  end

  def notify(label, event, data)
    listener.notify(label, event, data)
  rescue => e
    warnonce("Error during instrumentation notification: #{e}")
  end

  def listen_to?(label)
    enabled? and (!@pattern || @pattern === label.to_s)
  end

  def enabled?
    !!@enabled
  end

  def name
    @listener.name.to_s
  end

  def data
    { :data => @listener.data }
  end

  def to_pson(*args)
    result = {
      :document_type => "Puppet::Util::Instrumentation::Listener",
      :data => {
        :name => name,
        :pattern => pattern,
        :enabled => enabled?
      }
    }
    result.to_pson(*args)
  end

  def self.from_pson(data)
    result = Puppet::Util::Instrumentation[data["name"]]
    self.new(result.listener, result.pattern, data["enabled"])
  end
end
