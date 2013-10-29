module Puppet
  class Network::AuthCommand
    def initialize(path)
      @path = path
    end
    def allowed?(name, addr)
      Puppet::Util::Execution.execute([@path, name, addr], :failonfail => false)
      $CHILD_STATUS.exitstatus == 0
    end
  end
end
