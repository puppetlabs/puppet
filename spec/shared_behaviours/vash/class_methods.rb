require 'puppet/util/vash/errors'

module Puppet::SharedBehaviours; module Vash; end; end

module Puppet::SharedBehaviours::Vash

  module ClassMethodsMod

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
      rescue Puppet::Util::Vash::VashArgumentError => err
        raise err.class, err.to_s
      end
      obj
    end
  end
end

class Puppet::SharedBehaviours::Vash::ClassMethods
  extend Puppet::SharedBehaviours::Vash::ClassMethodsMod
end
