# A type of log destination.
class Puppet::Util::Log::Destination
  class << self
    attr_accessor :name
  end

  def self.initvars
    @matches = []
  end

  # Mark the things we're supposed to match.
  def self.match(obj)
    @matches ||= []
    @matches << obj
  end

  # See whether we match a given thing.
  def self.match?(obj)
    # Convert single-word strings into symbols like :console and :syslog
    if obj.is_a? String and obj =~ /^\w+$/
      obj = obj.downcase.intern
    end

    @matches.each do |thing|
      # Search for direct matches or class matches
      return true if thing === obj or thing == obj.class.to_s
    end
    false
  end

  def name
    if defined?(@name)
      return @name
    else
      return self.class.name
    end
  end

  # Set how to handle a message.
  def self.sethandler(&block)
    define_method(:handle, &block)
  end

  # Mark how to initialize our object.
  def self.setinit(&block)
    define_method(:initialize, &block)
  end
end

