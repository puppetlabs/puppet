require 'spec_helper'
require 'puppet/util/vash/contained'
require 'shared_behaviours/vash/contained'

class Vash_Contained
  include Puppet::Util::Vash::Contained
  def self.to_s; 'Vash::Contained'; end
  # accept only valid identifiers as keys
  def vash_valid_key?(key)
    key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)
  end
  # accept only what is convertible to integer
  def vash_valid_value?(val)
    true if Integer(val) rescue false
  end
  def vash_munge_key(key)
    key.gsub(/([a-z])([A-Z])/,'\1_\2').downcase
  end
  def vash_munge_value(val)
    Integer(val)
  end
  # for keys ending with _price we accept only non-negative values
  def vash_valid_pair?(pair)
    (pair[0]=~/price$/) ? (pair[1]>=0) : true
  end
  def vash_munge_pair(pair)
    [pair[0] + pair[1].to_s, pair[1]]
  end
end

# VASH_UNCOMMENT_START
# By default it's disabled in puppet distribution, as the number of tests
# generated here plus other puppet tests is able to kill CI systems (this was
# observed at least on travis-ci.org on ruby 1.8). 
if ENV['PUPPET_TEST_VASH'] or ENV['PUPPET_TEST_ALL']
# VASH_UNCOMMENT_END
  describe Vash_Contained do
    it_behaves_like 'Vash::Contained', {
      :valid_keys     => ['one', 'net_price', 'GrossPrice'],
      :invalid_keys   => [:one, 1, '#$', '' ],
      :valid_items    => [ ['a',1], ['b','2'] ],
      :invalid_items  => [
                           [ ['',      1],     :key],
                           [ ['price', 'one'], :value],
                           [ ['NetPrice', -1], :pair]
                         ],
      :hash_arguments => [
                           {'a'=>2, 'b'=>'-1'},   # all valid,
                           {:x =>0, 'x'=> '1'},   # invalid key
                           {'x'=>2, 'y'=> nil},   # invalid value,
                           {'thePrice'=>-1}       # invalid pair
                         ],
      :missing_key    => 'c',
      :missing_value  => '4',
      :methods        => {
        :vash_valid_key?   => lambda {|key| key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)},
        :vash_valid_value? => lambda {|val| true if Integer(val) rescue false },
        :vash_valid_pair?  => lambda {|pair| (pair[0]=~/price$/) ? (pair[1]>=0) : true},
        :vash_munge_key    => lambda {|key| key.gsub(/([a-z])([A-Z])/,'\1_\2').downcase},
        :vash_munge_value  => lambda {|val| Integer(val)},
        :vash_munge_pair   => lambda {|pair| [pair[0] + pair[1].to_s, pair[1]]}
      }
    }
  end
# VASH_UNCOMMENT_START
end
# VASH_UNCOMMENT_END
