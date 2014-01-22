require 'spec_helper'
require 'puppet/util/vash/errors'

module Puppet::SharedBehaviours;  end

module Puppet::SharedBehaviours::Vash
module ContainedMod

  require 'shared_behaviours/vash/validator'
  include ValidatorMod

  # @api private
  def self.included(base)
    base.extend(ClassMethodsMod)
  end
  require 'shared_behaviours/vash/class_methods'

  # @api private
  def vash_underlying_hash
    @vash_underlying_hash ||= {}
  end
  private :vash_underlying_hash

  # @api private
  def initialize_copy(other)
    super(other)
    @vash_underlying_hash = Hash[other]
    self
  end

  # @api private
  def initialize(*args,&block)
    super()
    @vash_underlying_hash = Hash.new(*args,&block)
  end

  private :initialize_copy

  require 'forwardable'
  extend ::Forwardable
  def_delegators :vash_underlying_hash,
    :==,
    :[],
    :assoc,
    :compare_by_identity?,
    :default,
    :default=,
    :default_proc,
    :default_proc=,
    :delete,
    :empty?,
    :eql?,
    :fetch,
    :flatten,
    :has_key?,
    :has_value?,
    :hash,
    :include?,
    :inspect,
    :key,
    :key?,
    :keys,
    :length,
    :member?,
    :rassoc,
    :shift,
    :size,
    :to_a,
    :to_h,
    :to_hash,
    :to_s,
    :value?,
    :values,
    :values_at

  ruby_version = 0;
  RUBY_VERSION.split('.').each{|x| ruby_version <<= 8; ruby_version |= x.to_i}

  # Same as {Hash#[]=}
  def []=(key, value)
    begin
      key,value = vash_validate_item([key, value])
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    vash_underlying_hash[key] = value
  end

  alias_method :store, :[]=

  # Same as {Hash#clear}
  def clear
    vash_underlying_hash.clear
    self
  end

  # Same as {Hash#compare_by_identity}
  def compare_by_identity
    vash_underlying_hash.compare_by_identity
    self
  end

  # Same as {Hash#delete_if}
  def delete_if(&block)
    result = vash_underlying_hash.delete_if(&block)
    block ? self : result
  end

  def each(&block)
    result = vash_underlying_hash.each(&block)
    block ? self : result
  end

  def each_key(&block)
    result = vash_underlying_hash.each_key(&block)
    block ? self : result
  end

  def each_pair(&block)
    result = vash_underlying_hash.each_pair(&block)
    block ? self : result
  end

  def each_value(&block)
    result = vash_underlying_hash.each_value(&block)
    block ? self : result
  end

  # Same as {Hash#rehash}
  def rehash
    vash_underlying_hash.rehash
    self
  end

  # Same as {Hash#invert}
  # @note Returning instance of self.class whould have no sense, especially
  # when key/value validation is in used, because keys and values may be
  # in different non-compatible domains, and we can't simply swap them and
  # put them back to an input validating hash. That's why this function must
  # return an instance of standard {Hash}.
  def invert
    hash = vash_underlying_hash.invert
  end

  if ruby_version >= 0x010903
  # @note This method is available on ruby>= 1.9.3 only.
  # Same as {Hash#keep_if}
  def keep_if(&block)
    result = vash_underlying_hash.keep_if(&block)
    block ?  self : result
  end
  end

  # Same as {Hash#merge!}
  def merge!(other, &block)
    begin
      other = vash_validate_hash(other)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    vash_underlying_hash.merge!(other, &block)
    self
  end

  alias_method :update, :merge!

  # Same as {Hash#merge}
  def merge(other, &block)
    begin
      self.dup.merge!(other, &block)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
  end

  # Same as {Hash#reject}
  def reject(&block)
    # note, using original 'reject' is more difficult here.
    self.dup.delete_if(&block)
  end

  # Same as {Hash#reject!}
  def reject!(&block)
    return nil if (result = vash_underlying_hash.reject!(&block)).nil?
    block ? self : result
  end

  # Same as {Hash#replace}
  def replace(other)
    begin
      other = vash_validate_hash(other)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    vash_underlying_hash.replace(other)
    self
  end

  # Similar to {Hash#select}
  # @note On ruby  1.8. the {Hash#select} returns an array (or enumerator)
  # and on 1.9.1+ returns hash (or enumerator). We always return hash or
  # an enumerator.
  #
  # Note, that for standard Hash and its subclasses we have
  # select{...}.class == Hash on ruby 1.9+.
  if ruby_version >= 0x010901
    def select(&block)
      vash_underlying_hash.select(&block)
    end
  else
    def select(&block)
      result = vash_underlying_hash.select(&block)
      block ? Hash[result] : result
    end
  end

  if ruby_version >= 0x010903
  # Same as {Hash#select!}
  def select!(&block)
    return nil if (result = vash_underlying_hash.select!(&block)).nil?
    block ? self : result
  end
  end

  #
  # extra methods for ClassMethods
  #

  # Replace Vash content with the one defined in array.
  #
  # Example
  #
  #     vash.replace_with_flat_array([:a, :A, :b, :B])
  #
  # The `vash` contents would be `{:a => :A, :b => :B}`
  def replace_with_flat_array(array)
    begin
      array = vash_validate_flat_array(array)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    vash_underlying_hash.replace(Hash[*array])
    self
  end

  # Replace Vash content with the one defined in array.
  #
  # Example
  #
  #     vash.replace_with_item_array([[:a, :A], [:b, :B]])
  #
  # The `vash` content would be `{:a => :A, :b => :B}`
  def replace_with_item_array(array)
    begin
      array = vash_validate_item_array(array)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    vash_underlying_hash.replace(Hash[array])
    self
  end
end
end

class Puppet::SharedBehaviours::Vash::Contained
  include Puppet::SharedBehaviours::Vash::ContainedMod
end

require 'shared_behaviours/vash/hash'
shared_examples 'Vash::Contained' do |_params|
  _sample_items =  (_params[:valid_items] || []) +
                   (_params[:invalid_items] || []).map{|item, guilty| item}
  _params = {
    :sample_items => _sample_items,
    :hash_initializers => [_params[:valid_items]] || [],
    :model_class  => Puppet::SharedBehaviours::Vash::Contained,
    # method exceptions
    :class_sqb=> { :raises=>[Puppet::Util::Vash::VashArgumentError, ArgumentError]},
    :[]=      => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :store    => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :replace  => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :merge    => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :merge!   => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :update   => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :replace_with_flat_array => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
    :replace_with_item_array => { :raises=>[Puppet::Util::Vash::VashArgumentError] },
  }.merge(_params)
  include_examples 'Vash::Validator', _params
  include_examples 'Vash::Hash', _params
end
