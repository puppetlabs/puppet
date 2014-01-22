require 'spec_helper'
require 'puppet/util/vash/validator'
require 'shared_behaviours/vash/validator'

class Vash_Validator_Unmodified
  include Puppet::Util::Vash::Validator
  def self.to_s; 'Vash::Validator[original]'; end
end

describe Vash_Validator_Unmodified do
  include_examples "Vash::Validator", { }
end

# sample hash which accepts integers or strings convertible to integers as an
# input, and ensures the relation value = key*key.
class Vash_Validator_Customized
  include Puppet::Util::Vash::Validator
  def self.to_s; 'Vash::Validator[customized]'; end
  # Choose to have our own names for keys, values and pairs.
  def vash_key_name(*args); 'power argument'; end
  def vash_value_name(*args); 'power value'; end
  def vash_pair_name(*args); 'power tuple'; end
  # Define constraints on keys, values and tuples
  def vash_valid_key?(key); true if Integer(key) rescue false; end
  def vash_valid_value?(val); true if Integer(val) rescue false; end
  def vash_valid_pair?(pair); pair[1] == pair[0]*pair[0]; end
  # Define our munging (consistent with validation)
  def vash_munge_key(key); Integer(key); end
  def vash_munge_value(val); Integer(val); end
  def vash_munge_pair(pair); pair.sort; end
end

# VASH_UNCOMMENT_START
# By default it's disabled in puppet distribution, as the number of tests
# generated here plus other puppet tests is able to kill CI systems (this was
# observed at least on travis-ci.org on ruby 1.8). 
if ENV['PUPPET_TEST_VASH'] or ENV['PUPPET_TEST_ALL']
# VASH_UNCOMMENT_END
  describe Vash_Validator_Customized do
    it_behaves_like "Vash::Validator", {
      :valid_keys          => [  0,  -1,'-1', 0.2 ],
      :invalid_keys        => [ 'a', {}, [1] ],
      :valid_values        => [  0,  -1,'-1', 0.2 ],
      :invalid_values      => [ 'a', {}, [1] ],
      :valid_pairs         => [ [1,1], [2,4], [3,9] ],
      :invalid_pairs       => [ [1,2], [2,1] ],
      :valid_items         => [ [2,4], ['3','9'] ],
      :invalid_items       => [
                                [ ['a', 0 ], :key   ],
                                [ ['a','A'], :key   ],
                                [ [ 0, 'A'], :value ],
                                [ [ 1,  2 ], :pair  ],
                                [ ['1','2'], :pair  ],
                              ],
      :key_munge_samples   => ['1', 1.1, 2],
      :value_munge_samples => ['1', 1.1, 2],
      :pair_munge_samples  => [[1,2], [4,3]],
      :methods             => {
        :vash_key_name     => lambda {|*args| 'power argument'},
        :vash_value_name   => lambda {|*args| 'power value'},
        :vash_pair_name    => lambda {|*args| 'power tuple'},
        :vash_munge_key    => lambda {|key| Integer(key)},
        :vash_munge_value  => lambda {|val| Integer(val)},
        :vash_munge_pair   => lambda {|pair| pair.sort}
      }
    }
  end
# VASH_UNCOMMENT_START
end
# VASH_UNCOMMENT_END
