require 'puppet/util/vash'
require 'puppet/util/vash/errors'

module Puppet::Util::Vash
module Inherited

  require 'forwardable'
  include ::Enumerable

  require 'puppet/util/vash/validator'
  include Validator

  def self.included(base)
    base.extend(ClassMethods)
  end
  require 'puppet/util/vash/class_methods'

  ruby_version = 0;
  RUBY_VERSION.split('.').each{|x| ruby_version <<= 8; ruby_version |= x.to_i}

  def []=(key, value)
    begin
      key, value = vash_validate_item([key, value])
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    self.class.superclass.instance_method(:store).bind(self).call(key,value)
  end
  alias_method :store, :[]=

  # Similar to {Hash#select}
  # @note On ruby  1.8. the {Hash#select} returns an array (or enumerator)
  # and on 1.9.1+ returns hash (or enumerator). We always return hash or
  # an enumerator.
  #
  # Note, that for Hash and its subclasses we have select{...}.class == Hash
  # on ruby 1.9+.
  if ruby_version < 0x010901
    def select(&block)
      result = self.class.superclass.instance_method(:select).bind(self).call(&block)
      block ? Hash[result] : result
    end
  end

  def merge!(other, &block)
    begin
      other = vash_validate_hash(other)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    self.class.superclass.instance_method(:merge!).bind(self).call(other, &block)
  end

  alias_method :update, :merge!

  def merge(other, &block)
    begin
      self.dup.merge!(other, &block)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
  end

  def replace(other)
    begin
      other = vash_validate_hash(other)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    self.class.superclass.instance_method(:replace).bind(self).call(other)
  end

  #
  # extra methods for ClassMethods
  #
  def replace_with_flat_array(array)
    begin
      array = vash_validate_flat_array(array)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    hash = Hash[*array]
    self.class.superclass.instance_method(:replace).bind(self).call(hash)
    self
  end

  def replace_with_item_array(array)
    begin
      array = vash_validate_item_array(array)
    rescue Puppet::Util::Vash::VashArgumentError => err
      raise err.class, err.to_s
    end
    hash = Hash[array]
    self.class.superclass.instance_method(:replace).bind(self).call(hash)
    self
  end

end
end
