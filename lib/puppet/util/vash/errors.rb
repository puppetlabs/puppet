require 'puppet/util/vash'
module Puppet::Util::Vash

  class VashArgumentError < ::ArgumentError; end
  class InvalidKeyError < VashArgumentError; end
  class InvalidValueError < VashArgumentError; end
  class InvalidPairError < VashArgumentError; end
  class OddArgNoError < VashArgumentError; end

end
