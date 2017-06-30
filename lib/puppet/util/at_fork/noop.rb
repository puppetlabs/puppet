# A noop implementation of the Puppet::Util::AtFork handler
class Puppet::Util::AtFork::Noop
  class << self
    def new
      # no need to instantiate every time, return the class object itself
      self
    end

    def prepare
    end

    def parent
    end

    def child
    end
  end
end
