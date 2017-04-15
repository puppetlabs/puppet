require 'puppet/util/vash'
require 'puppet/util/vash/errors'

module Puppet::Util::Vash

  # Class methods for {Puppet:Util::Vash::Contained}
  # and {Puppet::Util::Vash::Inherited}.
  #
  # Currently the following methods are added:
  #
  # - ::[]
  #
  # Requires the following instance methods to be defined in receiver class:
  #
  # - `#replace_with_flat_array(array)`
  # - `#replace_with_item_array(array)`
  # - `#replace(hash)`
  #
  # The abovementioned methods are also responsible for input validation and
  # munging.
  module ClassMethods

    # Same as Hash::[] but with input validation.
    def [](*args)
      obj = new()
      begin
        if args.length > 1
          obj.replace_with_flat_array(args)
        elsif args.length == 1
          if args[0].is_a?(Array)
            obj.replace_with_item_array(args[0])
          elsif args[0].is_a? Hash
            obj.replace(args[0])
          else
            obj.replace(Hash[args[0]])
          end
        end
      rescue VashArgumentError => err
        raise err.class, err.to_s
      end
      obj
    end
  end
end
