require 'hiera_puppet'

# Provides the block that defines the hiera, hiera_array, and hiera_hash functions. The only difference
# between those functions is the merge type (:priority, :array, or :hash) passed to the Hiera lookup. The
# definition contained here derives the merge type from the name of the function.
#
class Puppet::Functions::HieraFunction
  def self.common_layout
    proc do
      dispatch :hiera_array_param do
        scope_param
        param 'Tuple[String, Any, Any, 1, 3]', :args
      end

      dispatch :hiera_params do
        scope_param
        param 'String',:key
        param 'Any',   :default
        param 'Any',   :override
        arg_count(1,3)
      end

      dispatch :hiera_block_default do
        scope_param
        param 'String',        :key
        param 'Optional[Any]', :override
        required_block_param 'Callable[1,1]', :block
        arg_count(1,2)
      end

      def hiera_array_param(scope, args)
        hiera_params(scope, *args)
      end

      def hiera_params(scope, key, default = nil, override = nil)
        lookup(scope, key, default, override)
      end

      def hiera_block_default(scope, key, override = nil, block)
        undefined = (@@undefined_value ||= Object.new)
        result = lookup(scope, key, undefined, override)
        result.equal?(undefined) ? block.call(scope, key) : result
      end

      def lookup(scope, key, default, override)
        case self.class.name
        when 'hiera_hash'
          merge_type = :hash
        when 'hiera_array'
          merge_type = :array
        else
          merge_type = :priority
        end
        HieraPuppet.lookup(key, default,scope, override, merge_type)
      end
    end
  end
end
