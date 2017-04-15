require 'puppet/util/vash'

module Puppet::Util::Vash

  module Validator

    def vash_valid_key?(key); true; end
    def vash_valid_value?(value); true; end
    def vash_valid_pair?(pair); true; end
    def vash_munge_key(key); key; end
    def vash_munge_value(val); val; end
    def vash_munge_pair(pair); pair; end
    def vash_key_name(*args); 'key'; end
    def vash_value_name(*args); 'value'; end
    def vash_pair_name(*args); '(key,value) combination'; end

    def vash_validate_key(key,*args)
      raise *(vash_key_exception(key,*args)) unless vash_valid_key?(key)
      vash_munge_key(key)
    end

    def vash_validate_value(val,*args)
      raise *(vash_value_exception(val,*args)) unless vash_valid_value?(val)
      vash_munge_value(val)
    end

    def vash_validate_pair(pair,*args)
      raise *(vash_pair_exception(pair,*args)) unless vash_valid_pair?(pair)
      vash_munge_pair(pair)
    end

    def vash_validate_item(item,*args)
      k = vash_validate_key(*vash_select_key_args(item,*args))
      v = vash_validate_value(*vash_select_value_args(item,*args))
      vash_validate_pair(*vash_select_pair_args([k,v],*args))
    end

    def vash_validate_hash(hash)
      Hash[hash.map { |item| vash_validate_item(item) }]
    end

    def vash_validate_flat_array(array)
      def each_item_with_index(a)
        i = 0; l = a.length-1; while i<l do; yield [a[i,2],i]; i+=2; end
      end
      array2 = Array.new(array.length) # pre-allocate
      each_item_with_index(array) do |item,i|
        array2[i,2] = vash_validate_item(item,i,i+1)
      end
      array2
    end

    def vash_validate_item_array(array)
      def each_item_with_index(a)
        i = 0; l = a.length; while i<l do; yield [a[i],i]; i+=1; end
      end
      array2 = Array.new(array.length) # pre-allocate
      each_item_with_index(array) do |item,i|
        array2[i] = vash_validate_item(item,i)
      end
      array2
    end


    def vash_key_exception(key, *args)
      name = vash_key_name(key,*args)
      msg  = "invalid #{name} #{key.inspect}"
      msg += " at index #{args[0]}" unless args[0].nil?
      msg += " (with value #{args[1].inspect})" unless args.length < 2
      [InvalidKeyError, msg]
    end

    def vash_value_exception(value, *args)
      name = vash_value_name(value,*args)
      msg  = "invalid #{name} #{value.inspect}"
      msg += " at index #{args[0]}" unless args[0].nil?
      msg += " at key #{args[1].inspect}" unless args.length < 2
      [InvalidValueError, msg]
    end

    def vash_pair_exception(pair, *args)
      name =  vash_pair_name(pair,*args)
      msg  = "invalid #{name} (#{pair.map{|x| x.inspect}.join(',')})"
      msg += " at index #{args[0]}" unless args[0].nil?
      [InvalidPairError, msg]
    end

    def vash_select_key_args(item, *indices)
      indices.all?{|i| i.nil?}  ? item[0,1] : [item[0], indices[0]]
    end

    def vash_select_value_args(item, *indices)
      indices.all?{|i| i.nil?} ? [item[1],nil,item[0]] : [item[1],indices.last]
    end

    def vash_select_pair_args(item, *indices)
      [item, *indices]
    end
  end
end
