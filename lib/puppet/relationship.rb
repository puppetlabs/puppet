# subscriptions are permanent associations determining how different
# objects react to an event

# This is Puppet's class for modeling edges in its configuration graph.
# It used to be a subclass of GRATR::Edge, but that class has weird hash
# overrides that dramatically slow down the graphing.
class Puppet::Relationship

  # FormatSupport for serialization methods
  include Puppet::Network::FormatSupport
  include Puppet::Util::PsychSupport

  attr_accessor :source, :target, :callback

  attr_reader :event

  def self.from_data_hash(data)
    source = data['source']
    target = data['target']

    args = {}
    if event = data["event"]
      args[:event] = :"#{event}"
    end
    if callback = data["callback"]
      args[:callback] = :"#{callback}"
    end

    new(source, target, args)
  end

  def event=(event)
    #TRANSLATORS 'NONE' should not be translated
    raise ArgumentError, _("You must pass a callback for non-NONE events") if event != :NONE and ! callback
    @event = event
  end

  def initialize(source, target, options = {})
    @source, @target = source, target

    options = (options || {}).inject({}) { |h,a| h[a[0].to_sym] = a[1]; h }
    [:callback, :event].each do |option|
      if value = options[option]
        send(option.to_s + "=", value)
      end
    end
  end

  # Does the passed event match our event?  This is where the meaning
  # of :NONE comes from.
  def match?(event)
    if self.event.nil? or event == :NONE or self.event == :NONE
      return false
    elsif self.event == :ALL_EVENTS or event == self.event
      return true
    else
      return false
    end
  end

  def label
    result = {}
    result[:callback] = callback if callback
    result[:event] = event if event
    result
  end

  def ref
    "#{source} => #{target}"
  end

  def inspect
    "{ #{source} => #{target} }"
  end

  def to_data_hash
    data = {
      'source' => source.to_s,
      'target' => target.to_s
    }
    data['event'] = event.to_s unless event.nil?
    data['callback'] = callback.to_s unless callback.nil?
    data
  end

  def to_s
    ref
  end
end
