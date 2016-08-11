module Puppet::Pops
module Serialization
  # Implements all the constructors found in the Time class and ensures that
  # the created Time object can be serialized and deserialized using its
  # seconds and nanoseconds without loss of precision.
  #
  # @api public
  class TimeFactory

    NANO_DENOMINATOR = 10**9

    def self.at(*args)
      sec_nsec_safe(Time.at(*args))
    end

    def self.gm(*args)
      sec_nsec_safe(Time.gm(*args))
    end

    def self.local(*args)
      sec_nsec_safe(Time.local(*args))
    end

    def self.mktime(*args)
      sec_nsec_safe(Time.mktime(*args))
    end

    def self.new(*args)
      sec_nsec_safe(Time.new(*args))
    end

    def self.now
      sec_nsec_safe(Time.now)
    end

    def self.utc(*args)
      sec_nsec_safe(Time.utc(*args))
    end

    # Creates a Time object from a Rational defined as:
    #
    # (_sec_ * #NANO_DENOMINATOR + _nsec_) / #NANO_DENOMINATOR
    #
    # This ensures that a Time object can be reliably serialized and using its
    # its #tv_sec and #tv_nsec values and then recreated again (using this method)
    # without loss of precision.
    #
    # @param sec [Integer] seconds since Epoch
    # @param nsec [Integer] nano seconds
    # @return [Time] the created object
    #
    def self.from_sec_nsec(sec, nsec)
      Time.at(Rational(sec * NANO_DENOMINATOR + nsec, NANO_DENOMINATOR))
    end

    # Returns a new Time object that is adjusted to ensure that precision is not
    # lost when it is serialized and deserialized using its seconds and nanoseconds
    # @param t [Time] the object to adjust
    # @return [Time] the adjusted object
    #
    def self.sec_nsec_safe(t)
      from_sec_nsec(t.tv_sec, t.tv_nsec)
    end
  end
end
end
