require 'spec_helper'
require 'puppet/util/vash/errors'

module Puppet::SharedBehaviours; module Vash; end; end

#############################################################################
# Stable "snapshot" of the Puppet::Util::Vash::Validator module.
#
# This is a copy of stable and tested version of Validator module. In specs we
# compare behaviour of Puppet::Util::Vash::Validator against this
# module. If the behaviour of Puppet::Util::Vash::Validator diverges
# from this one, the specs should notify you about differences, and you'll be
# forced to revise your changes to implementation.
#
# You should update this copy each time you update successfuly
# Puppet::Util::Vash::Validator.
#
module Puppet::SharedBehaviours::Vash::ValidatorMod

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
    [Puppet::Util::Vash::InvalidKeyError, msg]
  end

  def vash_value_exception(value, *args)
    name = vash_value_name(value,*args)
    msg  = "invalid #{name} #{value.inspect}"
    msg += " at index #{args[0]}" unless args[0].nil?
    msg += " at key #{args[1].inspect}" unless args.length < 2
    [Puppet::Util::Vash::InvalidValueError, msg]
  end

  def vash_pair_exception(pair, *args)
    name =  vash_pair_name(pair,*args)
    msg  = "invalid #{name} (#{pair.map{|x| x.inspect}.join(',')})"
    msg += " at index #{args[0]}" unless args[0].nil?
    [Puppet::Util::Vash::InvalidPairError, msg]
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
#############################################################################


#############################################################################
# @todo write docs for Puppet::SharedBehaviours::Vash::Validator
# TODO: write docs for Puppet::SharedBehaviours::Vash::Validator
#
class Puppet::SharedBehaviours::Vash::Validator
  include Puppet::SharedBehaviours::Vash::ValidatorMod
end
#############################################################################


#############################################################################
# Test one of `vash_valid_key?`, `vash_valid_value?` or `vash_valid_pair?`
# methods.
#
# *Example*:
#
# In the following example we test `vash_valid_key?` which should return true
# only for strings.
#
#     describe "#vash_valid_key?" do
#       include_examples "Vash::Validator#vash_valid_single?", {
#         :type            => :key,
#         :validator       => described_class.new,
#         :valid_samples   => ['a', 'A'],
#         :invalid_samples => [nil, {}, :a]
#       }
#     end
#
# Required `_params`:
#
#   * `:type` - one of `:key`, `:value`, or `:pair`. The tested method is
#     `#{type}_valid?`, for example (`_params[:type] == `:key`) `key_valid?`.
#   * `:validator` - an instance of tested class,
#   * `:valid_samples` - an array of values for which the tested method
#     returns true. Note: for pairs, this should be a `[key,value]` pair
#     (array) as returned by `#munge_pair` method.
#   * `:invalid_samples` - samples for which the tested method should return
#     `false`. The other rules are identical as for `:valid_samples`.
#
# You may pass empty arrays as `:valid_samples` and/or `:invalid_sampled`
# (this disables particular tests).
#############################################################################
shared_examples 'Vash::Validator#vash_valid_single?' do |_params|
  _type         = _params[:type].intern
  _validator    = _params[:validator]
  _is_valid_sym = "vash_valid_#{_type}?".intern
  _is_valid     = _validator.method(_is_valid_sym)

  let(:validator) { _params[:validator] }
  let(:is_valid)  { _is_valid }

  [[:valid, :be_true], [:invalid, :be_false]].each do |_state, _return_value|
    _samples = _params["#{_state}_samples".intern]
    _samples.each do |_sample|
      context "with #{_type}=#{_sample.inspect} (#{_state})" do
        let(:sample)       { _sample }
        let(:return_value) { _return_value }
        it { expect { is_valid.call(sample) }.to_not raise_error}
        it { is_valid.call(sample).should method(return_value).call }
      end
    end
  end
end
#############################################################################

#############################################################################
# Test one of `vash_munge_key`, `vash_munge_value` and `vash_munge_pair`
# methods.
#
# Example:
#
# In the following example we test `vash_munge_key` which is supposed to munge
# strings and symbols, and it should do this in same way as the `:model`
# object does.
#
#     describe "#vash_munge_key" do
#       include_examples 'Vash::Validator#vash_munge_single', {
#         :type       => :key,
#         :validator  => described_class.new,
#         :model      => model_class.new,
#         :samples    => ['a', 'A', :a]
#       }
#     end
#
# Required _params:
#
#   * `:type` - either `:key`, `:value` or `:pair`.
#   * `:validator` - an instance of tested class,
#   * `:model` - an instance of class having desired behaviour,
#   * `:samples` - an array of samples used to verify the behaviour.
#
#############################################################################
shared_examples 'Vash::Validator#vash_munge_single' do |_params|
  _type      = _params[:type].intern
  _validator = _params[:validator]
  _model     = _params[:model]
  _munge_sym = "vash_munge_#{_type}".intern

  _validator_munge = _validator.method(_munge_sym)
  _model_munge = _model.method(_munge_sym)

  let(:munge) { _validator_munge }

  _params[:samples].each do |_sample|
    _munged = _model_munge.call(_sample)
    context "with #{_type}=#{_sample.inspect}" do
      let(:sample) { _sample }
      let(:munged) { _munged }
      it { expect { munge.call(sample) }.to_not raise_error }
      it { munge.call(sample).should == munged }
    end
  end
end
#############################################################################

#############################################################################
# Test one of `vash_key_name`, `vash_value_name`, `vash_pair_name`,
# `vash_key_exception`, `vash_value_exception` or `vash_pair_exception`
# methods.
#
# *Example*:
#
# In the following example `vash_key_name` is supposed to return key names same
# way as the `:model` object does.
#
#     describe "#vash_key_name" do
#       include_examples 'Vash::Validator#vash_single_name_or_exception', {
#         :type       => :key,
#         :what       => :exception,
#         :validator  => described_class.new,
#         :model      => model_class.new,
#       }
#     end
#
# Required _params:
#
#   * `:type` - one of `:key`, `:value` or `:pair`.
#   * `:what` - one of `:name` or `:exception`,
#   * `:validator` - the validator to be tested,
#   * `:model` - a behaviour object taken as reference.
#
# Optional _params:
#
#   * `:samples` - an array of samples (keys, values or pairs, depending on
#     `:type` option). This is used only if `:tuples` are not provided.
#   * `:tuples` - an array of argument tuples for the tested method. For
#     example `[ [:a], [:a,:A] ]` will generate `vash_key_name(:a)` and
#     `vash_key_name(:a,:A)` cases, if `:type == :key` and `:what == :name`.
#
#############################################################################
shared_examples 'Vash::Validator#vash_single_name_or_exception' do |_params|
  _type      = _params[:type].intern
  _what      = _params[:what].intern
  _validator = _params[:validator]
  _model     = _params[:model]

  _query_sym = "vash_#{_type}_#{_what}".intern
  _validator_query = _validator.method(_query_sym)
  _model_query = _model.method(_query_sym)

  let(:query) { _validator_query }

  unless (_tuples = _params[:tuples])
    # these are calls, that may be done by standard Vash::Validator
    _tuples = case _what
              when :name; [[]] # vash_xxx_name accepts 0+ arguments.
              else;        []  # vash_xxx_exception accepts 1+ arguments.
              end
    _params[:samples].each do |_samp|
      _tuples += [ [_samp], [_samp,0], [_samp,0,:x] ]
    end
  end

  _tuples.each do |_arguments|
    _arguments_str = _arguments.map{|_x| _x.inspect}.join(', ')
    _return_value = _model_query.call(*_arguments)
    context "with arguments (#{_arguments_str})" do
      let(:arguments)     { _arguments }
      let(:return_value)  { _return_value }
      it { expect { err,msg = query.call(*arguments) }.to_not raise_error }
      case _what
      when :exception
        it "should be a pair of [ArgumentError, <String>]" do
          err, msg = query.call(*arguments)
          err.should <= ArgumentError
          msg.should be_a(::String)
        end
      when :name
        it { query.call(*arguments).should(be_a(String) || be_a(Symbol)) }
      end
      it { query.call(*arguments).should == return_value }
    end
  end
end
#############################################################################

##############################################################################
# Test one of `vash_validate_key`, `vash_validate_value` or
# `vash_validate_pair` methods.
#
# *Example*:
#
# In the following example, the tested method `vash_validate_key` is supposed
# to allow symbols and strings and raise exceptions for other objects.
#
#     describe "#vash_validate_key" do
#       include_examples 'Vash::Validator#vash_validate_single', {
#         :type => :key,
#         :validator       => described_class.new,
#         :model           => model_class.new,
#         :valid_samples   => [:a, :A, 'a'],
#         :invalid_samples => [1,nil,{},[]]
#       }
#     end
#
# Required _params:
#
#   * `:type` - one of `:key`, `:value` or `:pair`.
#   * `:validator` - an instance of the tested class,
#   * `:model` - a model object taken as reference,
#   * `:valid_samples` - an array with values, for which the method should
#     return normally
#   * `:invalid_samples` - an array with values, for which the method should
#     raise an exception.
#
# Optional _params:
#
#   * `:no_query_call` - if set to true, the tested implementation does not
#     invoke `vash_xxx_valid?` method (and this is intentionally).
#   * `:no_exception_call` - if set to true, the tested implementation does not
#     invoke `vash_xxx_exception` to get exception class and message (and this
#     is intentional).
#   * `:custom_exception` - if set to true, the tested implementation raises
#     custom exception when the check fails (still the exception is checked if it
#     is a kind of `::ArgumentError`)
#
##############################################################################
shared_examples 'Vash::Validator#vash_validate_single' do |_params|
  _type                = _params[:type]
  _validator           = _params[:validator]
  _model               = _params[:model]
  _validate_sym        = "vash_validate_#{_type}".intern
  _exception_sym       = "vash_#{_type}_exception".intern
  _query_sym           = "vash_valid_#{_type}?".intern
  _validator_validate  = _validator.method(_validate_sym)
  _model_validate  = _model.method(_validate_sym)
  _model_exception = _model.method(_exception_sym)

  let(:validator)     { _validator }
  let(:exception_sym) { _exception_sym }
  let(:query_sym)     { _query_sym }
  let(:validate)      { _validator_validate }

  _params[:valid_samples].each do |_sample|
    _tuples = [ [_sample], [_sample,0], [_sample,0,:x]  ]
    _tuples.each do |_arguments|
      _return_value  = _model_validate.call(*_arguments)
      _arguments_str = _arguments.map{|x| x.inspect}.join(',')
      context "##{_validate_sym}(#{_arguments_str}) [#{_type} valid]" do
        let(:sample)        { _sample }
        let(:arguments)     { _arguments }
        let(:return_value)  { _return_value }
        it { expect { validate.call(*arguments) }.to_not raise_error }
        it { validate.call(*arguments).should == return_value }
        unless _params[:no_query_call]
          it "should invoke ##{_query_sym}(#{_sample}) once" do
            validator.expects(query_sym).once.with(sample).returns(true)
            validate.call(*arguments)
          end
        end
      end
    end
  end

  _params[:invalid_samples].each do |_sample|
    _tuples = [ [_sample], [_sample,0], [_sample,0,:x]  ]
    _tuples.each do |_arguments|
      _arguments_str = _arguments.map{|x| x.inspect}.join(',')
      _err, _msg = _model_exception.call(*_arguments)
      context "##{_validate_sym}(#{_arguments_str}) [#{_type} invalid]" do
        let(:err)       { _err }
        let(:msg)       { _msg }
        let(:sample)    { _sample }
        let(:arguments) { _arguments }
        if _params[:custom_exception]
          it { expect { validate.call(*arguments) }.to raise_error ArgumentError }
        else
          it { expect { validate.call(*arguments) }.to raise_error err, msg }
        end
        unless _params[:no_query_call]
          it "should invoke ##{_query_sym}(#{_sample.inspect}) once" do
            validator.expects(query_sym).once.with(sample).returns(false)
            begin
              validate.call(*arguments)
            rescue err, msg
              # eat exception
            end
          end
        end
        unless _params[:no_exception_call]
          it "should invoke ##{_exception_sym}(#{_arguments_str}) once" do
            validator.expects(exception_sym).once.with(*arguments).returns([err,msg])
            begin
              validate.call(*arguments)
            rescue err, msg
              # eat exception
            end
          end
        end
      end
    end
  end
end
#############################################################################

##############################################################################
# Test one of `vash_validate_item`, `vash_validate_hash`,
# `vash_validate_flat_array` or `vash_validate_item_array` methods.
#
# *Example*:
#
# In the following example we test item validator which accepts only items
# with integer keys/values and keys being less than values.
#
#     describe "#vash_validate_item" do
#       include_examples 'Vash::Validator#vash_validate_input', {
#         :type            => :item,
#         :validator       => described_class.new,
#         :model           => model_class.new,
#         :valid_samples   => [ [0,1], [0,2], [1,2] ],
#         :invalid_samples => [
#                               [ [:a,  0], :key ],
#                               [ [:a, :A], :key ],
#                               [ [ 0, :A], :value ],
#                               [ [ 2,  1], :pair ]
#                             ]
#       }
#     end
#
# The elements in `:invalid_samples` are `[ item, guilty ]` pairs, where
# `item = [key,value]` pair and `guilty` tells what is wrong in this item.
# Possible values for `guilty` are `:key`, `:value`, `:pair` (key and value
# are correct, but they doesn't form valid pair).
#
# Required _params:
#
#   * `:type` - one of `:item`, `:hash`, `:flat_array` or `:iten_array`.
#   * `:validator` - an instance of the tested class,
#   * `:model` - a behaviour object taken as reference,
#   * `:valid_samples` - an array with samples, for which the method should
#     return normally. Following rules apply:
#
#     * if `:type` is `:item`, then `:valid_samples` must be an array of
#       key-value pairs,
#     * if `:type` is `:hash`, then `:valid_samples` must be an array of
#       hashes,
#     * if `:type` is `:flat_array`, then `:valid_samples` must be an array of
#       flat arrays containing keys interleaved with values, for example:
#       `[ [ :k1a, :v1a, :k2a, :v2a ], [ :k1b, :v1b, :k2b, :v2b ] ]`,
#     * if `:type` is `:item_array`, then `:valid_samples` must be an array of
#       item arrays, each one containing key,value pairs as 2-element arrays,
#       for exapmle `[ [ [:k1a,:v1a], [:k2a,:v2a] ], [ [:k1b,:v1b] ]  ]`,
#
#   * `:invalid_samples` - an array with samples, for which the method should
#     raise an exception. Each sample in array is a pair of type:
#
#         [
#           object, [guilty, item, indices]
#         ]
#
#      where object is an item (if `:type` is `:item`), a hash (if `:type` is
#      `:hash`), a flat array or item array (if `:type` is `:flat_array` or
#      `:item_array` respectively). The `guilty` may be one of `:key`,
#      `:value` or `:pair` and indicates, what is wrong with the first item
#      that doesn't pass validation. The `item` is a copy of item that causes
#      validation to fail. The indices have sense only for `:flat_array` and
#      `:item_array`. For `:flat_array` this should be a tuple with indices
#      position indices of key and value for the failing item (this should
#      be normally `i` and `i+1`, for an item starting at position `i`).
#      For `:item_array`, this should be one-element array with the index
#      of failing item. For `:hash`, this should be an empty array. For
#      `:item` it is irrelevant.
#
#
# Optional _params:
#
#   * `:custom_exception` - if set to true, the tested implementation raises
#     custom exception when the check fails (still the exception is checked if
#     it is a kind of `::ArgumentError`)
#
##############################################################################
shared_examples 'Vash::Validator#vash_validate_input' do |_params|

  _type                = _params[:type].intern
  _validator           = _params[:validator]
  _model               = _params[:model]
  _validate_sym        = "vash_validate_#{_type}".intern
  _validator_validate  = _validator.method(_validate_sym)
  _model_validate  = _model.method(_validate_sym)
  _validator_validate  = _validator.method(_validate_sym)

  let(:validator)     { _validator }
  let(:validate)      { _validator_validate }

  case _type
  when :item
    _tuples_num  = 3
    _arg_name    = :item
    _return_type = Array
  when :hash
    _tuples_num  = 1
    _arg_name    = :hash
    _return_type = Hash
  when :flat_array
    _tuples_num  = 1
    _arg_name    = :array
    _return_type = Array
  when :item_array
    _tuples_num  = 1
    _arg_name    = :array
    _return_type = Array
  else
    raise ArgumentError, "unsupported type: #{_type}"
  end

  let(:return_type) { _return_type }

  _params[:valid_samples].each do |_sample|
    _tuples = [ [_sample], [_sample,0], [_sample,0,1] ][0,_tuples_num]
    _tuples.each do |_arguments|
      _sample,*_indices = _arguments
      _arguments_str = _arguments.map{|x| x.inspect}.join(',')
      # note, if the following command raises an exception (saying "invalid
      # key/value/item") then either valid_samples are not valid in fact, or
      # your `:model` object miss-behaves)
      _return_value = _model_validate.call(*_arguments)
      _return_size  = _sample.length
      context "##{_validate_sym}(#{_arguments_str}) [#{_arg_name} valid]" do
        let(:sample)       { _sample }
        let(:arguments)    { _arguments }
        let(:return_value) { _return_value }
        let(:return_size)  { _return_size }
        let(:expect_calls) { _expect_calls }
        it { expect { validate.call(*arguments) }.to_not raise_error }
        it { validate.call(*arguments).should be_an return_type }
        it "size of the returned #{_return_type} should be #{_return_size}" do
          validate.call(*arguments).size.should == return_size
        end
        it { validate.call(*arguments).should == return_value }
      end
    end
  end

  _params[:invalid_samples].each do |_sample, _guilty|
    _g_type, _g_item, _g_indices = _guilty
    _g_type = _g_type.intern
    _tuples = [ [_sample], [_sample,0], [_sample,0,1]  ][0, _tuples_num]
    _tuples.each do |_arguments|
      if _type == :item
        _g_item, *_g_indices = _arguments
      end
      _except = _model.method("vash_#{_g_type}_exception".intern)
      _select = _model.method("vash_select_#{_g_type}_args".intern)
      _g_args = case _g_type
                when :pair
                  _key = _model.vash_munge_key(_g_item[0])
                  _val = _model.vash_munge_value(_g_item[1])
                  _select.call([_key,_val],*_g_indices)
                else
                  _select.call(_g_item,*_g_indices)
                end
      _err, _msg = _except.call(*_g_args)
      _arguments_str = _arguments.map{|x| x.inspect}.join(',')
      context "##{_validate_sym}(#{_arguments_str}) [invalid #{_g_type}=#{_g_args[0].inspect}]" do
        let (:err)       { _err }
        let (:msg)       { _msg }
        let (:arguments) { _arguments }
        if _params[:custom_exception]
          it { expect { validate.call(*arguments) }.to raise_error ArgumentError }
        else
          it { expect { validate.call(*arguments) }.to raise_error err, msg }
        end
      end
    end
  end
end

##############################################################################
# Test all methods of Puppet::Util::Vash::Validator.
#
# This is unit test for Puppet::Util::Vash::Validator, but may be
# used to test customized validators as well. The basic usage is
#
#     require 'shared_behaviours/vash/validator'
#     # ...
#     include_examples 'Vash::Validator', _params
#
# when testing Puppet::Util::Vash::Validator, or
#
#     require 'shared_behaviours/vash/validator'
#     # ...
#     it_behaves_like 'Vash::Validator', _params
#
# An example of both - original and customized validators may be found in
# `spec/unit/util/vash/validator_spec.rb`.
#
# Options (all optional):
#
#   * `:valid_keys`    - sample keys, that must be accepted by key validator,
#   * `:invalid_keys`  - sample keys, that must be rejected by key validator,
#   * `:valid_pairs`   - sample pairs, that must be accepted by pair validator,
#   * `:invalid_pairs` - sample pairs, that must be rejected by pair validator,
#   * `:valid_items`   - sample items, that must be accepted by all validators
#     in the chain,
#   * `:invalid_items` - sample items, that must be rejected by one of the
#     validators inthe chain, the array contains information which validator
#     should reject given item,
#   * `:methods`      - procs/lambdas that indicate customization of the
#     default behaviour,
#   * `:model_class` - a class that indicates the desired behaviour, it
#     should have all the methods of `Vash::Validator` implemented,
#     and then these examples will check behaviour of the `described_class`
#     against the `:model`,
##############################################################################
shared_examples 'Vash::Validator' do |_params|
  _params = _params.dup
  model_class     = (_params.delete(:model_class) ||
                     Puppet::SharedBehaviours::Vash::Validator).dup
  # inject custom methods to the model
  (_params.delete(:methods) || []).each do |_method, _proc|
    model_class.send(:define_method, _method.intern, _proc)
  end

  let!(:subject) { described_class.new }

  it { should respond_to :vash_valid_key? }
  it { should respond_to :vash_valid_value? }
  it { should respond_to :vash_valid_pair? }
  it { should respond_to :vash_munge_key }
  it { should respond_to :vash_munge_value }
  it { should respond_to :vash_munge_pair }
  it { should respond_to :vash_key_name }
  it { should respond_to :vash_value_name }
  it { should respond_to :vash_pair_name }
  it { should respond_to :vash_validate_key }
  it { should respond_to :vash_validate_value }
  it { should respond_to :vash_validate_pair }
  it { should respond_to :vash_validate_item }
  it { should respond_to :vash_validate_hash }
  it { should respond_to :vash_validate_flat_array }
  it { should respond_to :vash_validate_item_array }
  it { should respond_to :vash_key_exception }
  it { should respond_to :vash_value_exception }
  it { should respond_to :vash_pair_exception }
  it { should respond_to :vash_select_key_args }
  it { should respond_to :vash_select_value_args }


  ######################################
  # specs for:
  #   vash_valid_key?,
  #   vash_valid_value?,
  #   vash_valid_pair?
  #
  [:key, :value, :pair].each do |_type|
    _method = "vash_valid_#{_type}?".intern
    describe "##{_method}(#{_type})" do
      include_examples "Vash::Validator#vash_valid_single?", {
        :type            => _type,
        :validator       => described_class.new,
        :valid_samples   => _params["valid_#{_type}s".intern] || [],
        :invalid_samples => _params["invalid_#{_type}s".intern] || []
      }.merge(_params[_method] || {})
    end
  end


  ######################################
  # specs for:
  #   vash_munge_key,
  #   vash_munge_value,
  #   vash_munge_pair
  #
  [:key, :value, :pair].each do |_type|
    _method = "vash_munge_#{_type}".intern
    describe "##{_method}(#{_type})" do
      include_examples "Vash::Validator#vash_munge_single", {
        :type      => _type,
        :validator => described_class.new,
        :model     => model_class.new,
        :samples   => _params["#{_type}_munge_samples".intern] || []
      }.merge(_params[_method] || {})
    end
  end

  ######################################
  # specs for:
  #   vash__key_name,
  #   vash_value_name,
  #   vash_pair_name,
  #   vash__key_exception,
  #   vash_value_exception,
  #   vash_pair_exception,
  #
  [
    [:key,   :a],
    [:value, :A],
    [:pair,  [:a,:A]]
  ].each do |_type,_proto|
    _samples  = (_params["valid_#{_type}s".intern] || [])[0,1]
    _samples += (_params["invalid_#{_type}s".intern] || [])[0,1]
    _samples  = [_proto] if _samples.empty? # generate at least one test!

    [:name, :exception].each do |_what|
      _method      = "vash_#{_type}_#{_what}".intern
      _tuples      = _params["#{_method}_tuples".intern]
      describe "##{_method}(*args)" do
        include_examples 'Vash::Validator#vash_single_name_or_exception', {
          :type       => _type,
          :what       => _what,
          :validator  => described_class.new,
          :model      => model_class.new,
          :samples    => (_tuples ? nil : _samples),
          :tuples     => _tuples,
        }.merge(_params[_method] || {})
      end
    end
  end

  ######################################
  # specs for:
  #   vash_validate_key,
  #   vash_validate_value,
  #   vash_validate_pair
  #
  [:key, :value, :pair].each do |_type|
    _method = "vash_validate_#{_type}"
    describe "##{_method}(#{_type},*args)" do
      include_examples 'Vash::Validator#vash_validate_single', {
        :type            => _type,
        :validator       => described_class.new,
        :model           => model_class.new,
        :valid_samples   => _params["valid_#{_type}s".intern] || [],
        :invalid_samples => _params["invalid_#{_type}s".intern] || []
      }.merge(_params[_method] || {})
    end
  end


  ######################################
  # specs for:
  #   vash_validate_item,
  #   vash_validate_hash,
  #   vash_validate_flat_array,
  #   vash_validate_item_array,
  #
  [ :item, :hash, :flat_array, :item_array ].each do |_type|
    _method = "vash_validate_#{_type}"
    case _type
    when :item
      _valid_samples   = _params[:valid_items] || []
      _invalid_samples = _params[:invalid_items] || []
    when :hash
      _valid_samples = [ Hash[ _params[:valid_items] || [] ] ]
      _invalid_samples = (_params[:invalid_items] || []).map {|_item, _guilty|
        [ _valid_samples[0].merge(Hash[ [_item] ]), [_guilty,_item,[]] ]
      }
    when :flat_array
      _valid_samples = [ (_params[:valid_items] || []).flatten ]
      _len = _valid_samples[0].length
      _invalid_samples = (_params[:invalid_items] || []).map {|_item, _guilty|
        [ (_valid_samples[0] + [_item]).flatten, [_guilty, _item, [_len,_len+1] ] ]
      }
    when :item_array
      _valid_samples = [ _params[:valid_items] || [] ]
      _len = _valid_samples[0].length
      _invalid_samples = (_params[:invalid_items] || []).map {|_item, _guilty|
        [ _valid_samples[0] + [_item], [_guilty, _item, [_len]] ]
      }
    else
      raise NotImplementedError, "#{_type} case is not implemented!"
    end
    describe "##{_method}" do
      include_examples 'Vash::Validator#vash_validate_input', {
        :type            => _type,
        :validator       => described_class.new,
        :model           => model_class.new,
        :valid_samples   => _valid_samples,
        :invalid_samples => _invalid_samples,
      }.merge(_params[_method] || {})
    end
  end

end
