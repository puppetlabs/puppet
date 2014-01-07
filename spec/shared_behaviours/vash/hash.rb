require 'spec_helper'
require 'rspec/expectations'

def ruby_version
  ver = 0;
  RUBY_VERSION.split('.').each{|x| ver <<= 8; ver |= x.to_i}
  ver
end

def enumerator_class
  if ruby_version < 0x010900
    ::Enumerable::Enumerator
  else
    ::Enumerator
  end
end

def key_error_from_fetch
  begin
    {}.fetch('x')
  rescue => e
    e.class
  end
end


RSpec::Matchers.define :be_instance_of_one_of do |expected|
  unless expected.is_a?(Array)
    raise ArgumentError, 'argument must be an Array'
  end
  expected_repr = expected.map{|x| x.inspect}.join(' or ')
  match do |actual|
    expected.include? actual.class
  end
  failure_message_for_should do |actual|
    "expected that #{actual.inspect} would be an instance of " +
    "#{expected_repr} but it is an instance of #{actual.class}"
  end
  description do
    "be an instance of #{expected_repr}"
  end
end

RSpec::Matchers.define :be_enumerator_equivalent_to do |expected|
  unless expected.respond_to?(:to_a)
    raise ArgumentError, "wrong argument to match enumerator: #{expected.inspect}"
  end
  match do |actual|
    # compare unordered arrays
    a, e = actual, expected
    if ruby_version < 0x010901
      # on 1.8 we have random order of so a.to_a == e.to_a would work randomly
      Hash[a.zip(a.map{|x| a.count(x)})] == Hash[e.zip(e.map{|x| e.count(x)})]
    else
      a.to_a == e.to_a
    end
  end
  failure_message_for_should do |actual|
    actual_repr = "<#{actual.map{|x| x.inspect}.join(', ')}>"
    expected_repr = "<#{expected.map{|x| x.inspect}.join(', ')}>"
    "expected that #{actual_repr} would be an enumerator for #{expected_repr}"
  end
  description do
    expected_repr = "<#{expected.map{|x| x.inspect}.join(', ')}>"
    "be an enumerator for #{expected_repr}"
  end
end

module Puppet; module SharedBehaviours; module Vash; end; end; end

class Puppet::SharedBehaviours::Vash::Hash < ::Hash
  def self.to_s; 'Hash'; end
end

# Each method in this class returns an array of possible return classes
# for corresponding Hash method. If this information cannot be determined
# without knowing hash content, nil is returned.
class HashReturnTypes


  def initialize(subject_class)
    @subject_class = subject_class
  end

  def [](key); nil; end
  def []=(key,val); nil; end # can't predict, it may be munged
  def ==(other); [TrueClass,FalseClass]; end
  def assoc(obj); [Array, NilClass]; end
  def clear; [@subject_class]; end
  def compare_by_identity; [@subject_class]; end
  def compare_by_identity?; [TrueClass, FalseClass]; end
  def default(key=nil); nil; end
  def default=(obj); [obj.class]; end
  def default_proc; [Proc,NilClass]; end
  def default_proc=(obj); [obj.class,NilClass]; end
  def delete(key,&block); nil; end
  def delete_if(&block); (block ? [@subject_class] : [enumerator_class]); end
  def each(&block); (block ? [@subject_class] : [enumerator_class]); end
  def each_key(&block); (block ? [@subject_class] : [enumerator_class]); end
  def each_pair(&block); (block ? [@subject_class] : [enumerator_class]); end
  def each_value(&block); (block ? [@subject_class] : [enumerator_class]); end
  def empty?; [TrueClass,FalseClass]; end
  def eql?(other); [TrueClass,FalseClass]; end
  def fetch(key,default=nil,&block); nil; end
  def flatten(level=nil); [Array]; end
  def has_key?(key); [TrueClass, FalseClass]; end
  def has_value?(val); [TrueClass, FalseClass]; end
  def hash; [Fixnum]; end
  def include?(key); [TrueClass, FalseClass]; end
  def inspect; [String]; end
  def invert; [Hash]; end
  def keep_if(&block); (block ? [@subject_class] : [enumerator_class]); end
  def key(val); nil; end
  def key?(key); [TrueClass, FalseClass]; end
  def keys; [Array]; end
  def length; [Fixnum]; end
  def member?(key); [TrueClass, FalseClass]; end
  def merge(other,&block); [@subject_class]; end
  def merge!(other,&block); [@subject_class]; end
  def rassoc(obj); [Array,NilClass]; end
  def rehash; [@subject_class]; end
  def reject(&block); (block ? [@subject_class] : [enumerator_class]); end
  def reject!(&block); (block ? [@subject_class,NilClass] : [enumerator_class]); end
  def replace(other); [@subject_class]; end
  if ruby_version >= 0x010901
  def select(&block); (block ? [Hash] : [enumerator_class]); end
  else
  def select(&block); (block ? [Hash,Array] : [enumerator_class]); end
  end
  def select!(&block); (block ? [@subject_class,NilClass] : [enumerator_class]); end
  def shift; nil; end
  def size; [Fixnum]; end
  def store(key,val); nil; end # don't predict, it may be munged!
  def to_a; [Array]; end
  def to_h; [Hash]; end
  def to_hash; [(@subject_class<=Hash) ? @subject_class : Hash]; end
  def to_s; [String]; end
  def update(other,&block); [@subject_class]; end
  def value?(val); [TrueClass, FalseClass]; end
  def values; [Array]; end
  def values_at(*args); [Array]; end
end

# ::[]
shared_examples 'Vash::Hash::[]' do |_params|

  _model_class    = _params[:model_class]
  _initializers   = [ [], [{}], [[]] ] +
                    _params[:hash_arguments].map{|h| [Hash[h]]} +
                    _params[:hash_arguments].map{|h| [h.to_a]} +
                    _params[:hash_arguments].map{|h| h.to_a.flatten}

  let(:model_class) { _model_class }

  _raises = _params[:raises] || []
  _initializers.each do |_arguments|
    _arguments_str = _arguments.map{|x| x.inspect}.join(',')
    context "::[#{_arguments_str}]" do
      let(:arguments) { _arguments }
      begin
        _model_class[*_arguments]
      rescue *_raises => _except
        unless _params[:disable_exception_matching]
          let(:err) { _except.class }
          let(:msg) { _except.message }
          it { expect { described_class[*arguments] }.to raise_error err, msg }
        end
      else
        it { expect { described_class[*arguments] }.to_not raise_error }
        it { described_class[*arguments].should be_instance_of described_class }
      end
    end
  end

  _initializers.each do |_arguments|
    _arguments_str  = _arguments.map{|x| x.inspect}.join(', ')
    _left_hash_str  = "Hash[ #{described_class}[ #{_arguments_str} ] ]"
    context "#{_left_hash_str}" do
      let(:arguments) { _arguments }
      # note: we test content after [], not the '==' operator; that's why
      # Hash is used here (we use his '==' operator).
      begin
        _model_class[*_arguments]
      rescue *_raises => _except
        # already done ...
      else
        # note: we can't initialize right_hash as Hash[ *arguments ]
        # because we may have munging enabled!
        # we convert to hash, to use its == operator: our must be tested first!
        let(:left_hash)  { Hash[ described_class[*arguments] ] }
        let(:right_hash) { Hash[ model_class[*arguments] ]}
        it { left_hash.should ==right_hash }
      end
    end
  end

  context "::[nil]" do
    # we should raise same exceptions as the model_class does.
    begin
      _model_class[nil]
    rescue *_raises => _except
      unless _params[:disable_exception_matching]
        let(:msg) { _except.message }
        let(:err) { _except.class }
        it { expect { described_class[nil] }.to raise_error err, msg }
      end
    else
      it { expect { described_class[nil] }.to_not raise_error }
    end
  end

end

# ::new
shared_examples 'Vash::Hash::new' do
  it "::new should not raise error" do
    expect { described_class.new }.to_not raise_error
  end
  it "::new.default should be nil" do
    described_class.new.default.should be nil
  end
  it "::new(:A) should not raise error" do
    expect { described_class.new(:A) }.to_not raise_error
  end
  it "::new(:A).default shoule be :A" do
    described_class.new(:A).default.should equal :A
  end
  it "::new{|h,k| k*k} should not raise error" do
    expect { described_class.new {|h,k| k*k} }.to_not raise_error
  end
  it "::new{|h,k| k*k}[2] should be 4" do
    described_class.new{|h,k| k*k}[2].should == 4
  end
end

def invoke(_method, _args, _block)
  if _block
    _method.call(*_args) { |*_args2| _block.call(*_args2) }
  else
    _method.call(*_args)
  end
end

shared_examples 'Vash::Hash#spec_method:call:check_exception' do
  it do
    begin
      invoke(model_method,args,block)
    rescue *raises => except
      err, msg = except.class, except.message
    else
      raise 'spec failed: expected model to raise exception but nothing was raised'
    end
    expect { invoke(subject_method,args,block) }.to raise_error err, msg
  end
end

shared_examples 'Vash::Hash#spec_method:call:check_result' do \
  |_params,_model,_method,_args,_block,_expected|
  # returned types
  _return_types_get = HashReturnTypes.new(_model.class).method(_method)

  # return types - if we have some prescribed rules for the model, then similar
  # rules must be obeyed by subject
  unless _params[:disable_class_check]
    if _return_types = invoke(_return_types_get,_args,_block)
      let(:return_types_get) { HashReturnTypes.new(subject.class).method(_method) }
      let(:return_types)     { invoke(return_types_get,args,block) }
      it { invoke(subject_method,args,block).should be_instance_of_one_of return_types }
    end
  end
  # match the value returned by subject_method to that returned by
  # model_method
  unless _params[:disable_value_matching]
    it do
      expected = invoke(model_method,args,block)
      actual   = invoke(subject_method,args,block)
      if expected.instance_of?(enumerator_class)
        actual.should be_enumerator_equivalent_to expected
      elsif expected.is_a?(Array)
        actual.should =~ expected
      else
        actual.should == expected
      end
    end
  end
  # for some functions we must ensure, that 'self' is returned
  unless _params[:disable_value_is_self_check]
    if _expected.equal?(_model)
      # if model_method returns model, then probably subject_method should
      # return subject (by the "symmetry")
      unless [:to_h, :to_hash].include?(_method) and not _params[:subject].is_a?(Hash)
        it "should be self (identity match)" do
          invoke(subject_method,args,block).should be subject
        end
      end
    end
  end
end

# The workhorse
shared_examples 'Vash::Hash#spec_method:call' do |_params|
  _model    = _params[:model].dup
  _method   = _params[:method]
  _args     = _params[:args]
  _block    = _params[:block]
  _raises   = _params[:raises] || []

  let(:subject)         { _params[:subject].dup }
  let(:model)           { _params[:model].dup }
  let(:subject_method)  { subject.method(_params[:method]) }
  let(:model_method)    { model.method(_params[:method]) }
  let(:args)            { _args }
  let(:block)           { _block }
  let(:method_sym)      { _method }
  let(:raises)          { _raises }

  # check, if we should specify return value or exception
  begin
    _model_method = _model.method(_method)
    _expected = invoke(_model_method, _args, _block)
  rescue *_raises => _except # XXX: we trust our model a little bit too much!
    # exception
    unless _params[:disable_exception_matching]
      include_examples 'Vash::Hash#spec_method:call:check_exception'
    end
  else
    # return value
    it { expect { invoke(subject_method,args,block) }.to_not raise_error }
    context "the returned value" do
      include_examples 'Vash::Hash#spec_method:call:check_result',
        _params, _model, _method, _args, _block, _expected
    end
    # attributes
    (_params[:match_attributes_at_end] || []).each do |_property|
      context "the ##{_property} after operation" do
        let(:property) { _property }
        it do
          invoke(model_method,args,block)
          invoke(subject_method,args,block)
          subject.method(property).call.should == model.method(property).call
        end
      end
    end
    # content
    unless _params[:disable_content_matching]
      context 'the content after operation' do
        it do
          invoke(model_method,args,block)
          invoke(subject_method,args,block)
          subject.should == model
        end
      end
    end
  end
end
#
shared_examples 'Vash::Hash#spec_method:calls' do |_params|
  _blocks = _params[:blocks] || [nil]
  _tuples = _params[:tuples] || [[]]
  _blocks.each do |_block,_code|
    _tuples.each do |_args|
      _args_str = _args.map{|x| x.inspect}.join(', ')
      _context_title = case _params[:method]
        when :[]; "#[#{_args_str}]"
        when :==; "#{_params[:subject].inspect} == #{_args_str}"
        else;     "##{_params[:method]}" + (_args.empty? ? '' : "(#{_args_str})")
      end
      _context_title += " { #{_code} }" if _block
      context _context_title do
        include_examples 'Vash::Hash#spec_method:call', {
          :args     => _args,
          :block    => _block,
        }.merge(_params || {})
      end
    end
  end
end
#
shared_examples 'Vash::Hash#spec_method' do |_params|
  _method  = _params[:method]
  _params[:cases].each do |_case|
    context "when self is initialized with #{_case[:subject].inspect}" do
      (_params[:match_attributes] || []).each do |_property|
        context "the ##{_property} initially" do
          subject        { _case[:subject].dup }
          let(:model)    { _case[:model].dup }
          let(:property) { _property }
          it { subject.method(property).call.should == model.method(property).call }
        end
      end
      include_examples 'Vash::Hash#spec_method:calls', {
        :tuples    => _case[:tuples],
        :blocks    => _case[:blocks],
        :subject   => _case[:subject],
        :model     => _case[:model],
      }.merge(_params || {})
    end
  end
end

# Test method with prescribed set of initializers and argument tuples
shared_examples 'Vash::Hash#spec_method_with' do |_params,*_tuples|
  _initializers = _params[:hash_initializers] || [_params[:sample_items]] || []
  _cases = [
    {
      :subject   => described_class.new,
      :model     => _params[:model_class].new,
      :blocks    => _params[:blocks],
      :tuples    => _tuples
    },
  ]
  _initializers.each do |_initializer|
    _cases << {
      :subject   => described_class[_initializer],
      :model     => _params[:model_class][_initializer],
      :blocks    => _params[:blocks],
      :tuples    => _tuples
    }
  end
  include_examples 'Vash::Hash#spec_method', {
    :cases => _cases
  }.merge(_params||{})
end

# Test method that accept no arguments
shared_examples 'Vash::Hash#spec_method_with_no_arg' do |_params|
  include_examples 'Vash::Hash#spec_method_with', _params, []
end

# Test method that accept key as an argument
shared_examples 'Vash::Hash#spec_method_with_key_arg' do |_params|
  _missing_key  = _params[:missing_key]
  _sample_items = _params[:sample_items] || []
  _args = [[_missing_key], *(_sample_items.map{|k,v| [k]}) ]
  include_examples 'Vash::Hash#spec_method_with', _params, *_args
end

# Test method that accept value as an argument
shared_examples 'Vash::Hash#spec_method_with_value_arg' do |_params|
  _missing_value  = _params[:missing_value]
  _sample_items = _params[:sample_items] || []
  _args = [[_missing_value], *(_sample_items.map{|k,v| [k]}) ]
  include_examples 'Vash::Hash#spec_method_with', _params, *_args
end

# Test method that accept item as an argument
shared_examples 'Vash::Hash#spec_method_with_item_arg' do |_params|
  _missing_item  = [ _params[:missing_key],  _params[:missing_value] ]
  _existing_item = [ _params[:existing_key], _params[:existing_value] ]
  _args = [_missing_item, _existing_item]
  include_examples 'Vash::Hash#spec_method_with', _params, *_args
end

# Test method that accept other hash as argument
shared_examples 'Vash::Hash#spec_method_with_hash_arg' do |_params|
  _hash_arguments = _params[:hash_arguments]
  _args = (_params[:hash_arguments] || [{}]).map{|h| [h]}
  include_examples 'Vash::Hash#spec_method_with', _params, *_args
end


#############################################################################
shared_examples 'Vash::Hash' do |_params|

  _params = _params.dup

  _model_class = (_params.delete(:model_class) ||
                  Puppet::SharedBehaviours::Vash::Hash).dup

  # inject custom methods to the model
  (_params.delete(:methods) || []).each do |_method_sym, _method_proc|
    _model_class.send(:define_method, _method_sym.intern, _method_proc)
  end


  [
    :==, :[], :[]=, :clear, :default, :default=, :default_proc, :delete,
    :delete_if, :each, :each_key, :each_pair, :each_value, :empty?, :eql?,
    :fetch, :has_key?, :has_value?, :hash, :include?, :inspect, :invert,
    :key?, :keys, :length, :member?, :merge, :merge!, :rehash,
    :reject!, :reject, :replace,  :select, :shift, :size, :store, :to_a,
    :to_hash, :to_s, :update, :value?, :values, :values_at
  ].each do |method|
    it { should respond_to method }
  end

  if ruby_version >= 0x010901
    it { should respond_to :assoc }
    it { should respond_to :compare_by_identity }
    it { should respond_to :compare_by_identity? }
    it { should respond_to :default_proc= }
    it { should respond_to :flatten }
    it { should respond_to :key }
    it { should respond_to :rassoc }
  end

  if ruby_version >= 0x010903
    it { should respond_to :keep_if }
    it { should respond_to :select! }
  end

  if ruby_version >= 0x020000
    it { should respond_to :to_h }
  end

  _methods_with = {}
  _methods_with[:no_arg] = [
    :clear, :delete_if, :each, :each_key, :each_value, :each_pair, :empty?,
    :hash, :inspect, :invert, :keys, :length, :rehash, :reject, :reject!,
    :select, :shift, :size, :to_a, :to_hash, :values
  ]
  _methods_with[:key_arg] = [
    :[], :delete, :fetch, :has_key?, :include?, :key?, :member?
  ]
  _methods_with[:value_arg] = [
    :has_value?, :value?,
  ]
  _methods_with[:item_arg] = [
    :[]=, :store,
  ]
  _methods_with[:hash_arg] = [
    :==, :eql?, :merge!, :merge, :replace, :update,
  ]

  if ruby_version >= 0x010901
    _methods_with[:no_arg]    += [ :flatten ]
    _methods_with[:key_arg]   += [ :assoc, :rassoc ]
    _methods_with[:value_arg] += [ :key ]
  end

  if ruby_version >= 0x010903
    _methods_with[:no_arg]    += [ :select! ]
  end

  if ruby_version >= 0x020000
    _methods_with[:no_arg] += [ :to_h, :keep_if ]
  end

  _method_params = {
    :class_sqb=> {
      :raises => [ArgumentError]
    },
    :fetch    => {
      :raises => [key_error_from_fetch]
    },
  }

  if ruby_version < 0x020000
    # on these versions hash ordering is not guaranted, and shift may return
    # arbitrary item from hash.
    _method_params[:shift]||= {}
    _method_params[:shift][:disable_value_matching]    = true
    _method_params[:shift][:disable_content_matching] = true
  end

  _missing_key    = _params[:missing_key]
  _missing_value  = _params[:missing_value]
  _existing_key   = if _params.include? :existing_key; _params[:existing_key]
                    else; _params[:sample_items].first[0]; end
  _existing_value = if _params.include? :existing_value; _params[:existing_value]
                    else; _params[:sample_items].first[1]; end

  _method_blocks    = {
    :delete    => [ nil,
                    [ proc {|k| _missing_value},
                           "|k| #{_missing_value.inspect}" ] ],
    :delete_if => [ nil,
                    [ proc {|k,v| k ==   _missing_key},
                           "|k,v| k == #{_missing_key.inspect}"
                    ], [
                      proc {|k,v| k ==   _existing_key},
                           "|k,v| k == #{_existing_key.inspect}" ]
                  ],
    :each      => [ nil,
                    [
                      proc {|x| x},
                           "|x| x"
                    ],
                  ],
    :each_key  => [ nil,
                    [
                      proc {|k| k},
                           "|k| k"
                    ],
                  ],

    :each_pair => [ nil,
                    [
                      proc {|k,v| [k,v]},
                           "|k,v| [k,v]"
                    ],
                  ],
    :each_value=> [ nil,
                    [
                      proc {|v| v},
                           "|v| v"
                    ],
                  ],
    :fetch     => [ nil, [ proc {|k| _missing_value},
                                "|k| #{_missing_value.inspect}" ] ],
    :merge     => [ nil, [ proc {|k,o,n| o },   "|k,o,n| o" ] ],
    :merge!    => [ nil, [ proc {|k,o,n| o },   "|k,o,n| o" ] ],
    :reject    => [ nil,
                    [
                      proc {|k,v| k == _existing_key},
                           "|k,v| k == #{_existing_key.inspect}"
                    ],[
                      proc {|k,v| k == _missing_key},
                           "|k,v| k == #{_missing_key.inspect}"
                    ]
                  ],
    :reject!   => [ nil,
                    [
                      proc {|k,v| k == _existing_key},
                           "|k,v| k == #{_existing_key.inspect}"
                    ],[
                      proc {|k,v| k == _missing_key},
                           "|k,v| k == #{_missing_key.inspect}"
                    ]
                  ],
    :select    => [ nil,
                    [
                      proc {|k,v| k == _existing_key},
                           "|k,v| k == #{_existing_key.inspect}"
                    ],[
                      proc {|k,v| k == _missing_key},
                           "|k,v| k == #{_missing_key.inspect}"
                    ]
                  ],
    :select!   => [ nil,
                    [
                      proc {|k,v| k == _existing_key},
                           "|k,v| k == #{_existing_key.inspect}"
                    ],[
                      proc {|k,v| k == _missing_key},
                           "|k,v| k == #{_missing_key.inspect}"
                    ]
                  ],
    :update    => [ nil, [ proc {|k,o,n| o },   "|k,o,n| o" ] ],
    :update!   => [ nil, [ proc {|k,o,n| o },   "|k,o,n| o" ] ],
  }

  describe '::[]' do
    include_examples 'Vash::Hash::[]', {
      :model_class  => _model_class,
      :sample_items => _params[:sample_items],
    }.merge(_method_params[:class_sqb] || {}).
      merge(_params).
      merge(_params[:class_sqb] || {})
  end

  describe '::new' do
    include_examples 'Vash::Hash::new'
  end

  [:no_arg, :key_arg, :value_arg, :item_arg, :hash_arg].each do |_variant|
    _methods_with[_variant].each do |_method|
      describe "##{_method}" do
        include_examples "Vash::Hash#spec_method_with_#{_variant}", {
          :method          => _method,
          :blocks          => _method_blocks[_method],
          :model_class     => _model_class,
        }.merge(_method_params[_method] || {}).
          merge(_params).
          merge(_params[_method] || {})
      end
    end
  end

  if ruby_version >= 0x010901
    describe "#compare_by_identity?" do
      include_examples 'Vash::Hash#spec_method_with', {
        :method                   => :compare_by_identity?,
        :model_class              => _model_class,
        :hash_initializers        => [],
      }.merge(_params).merge(_params[:compare_by_identity]||{}), []
    end
    describe "#compare_by_identity" do
      include_examples 'Vash::Hash#spec_method_with', {
        :method                   => :compare_by_identity,
        :model_class              => _model_class,
        :hash_initializers        => [],
        :match_attributes         => [:compare_by_identity?],
        :match_attributes_at_end  => [:compare_by_identity?],
        :disable_value_matching   => true, # we compare by identity!
        :disable_content_matching => true  # we compare by identity!
      }.merge(_params).merge(_params[:compare_by_identity]||{}), []
    end
  end

  describe "#default" do
    include_examples 'Vash::Hash#spec_method_with', {
      :method                   => :default,
      :model_class              => _model_class,
      :hash_initializers        => [],
    }.merge(_params).merge(_params[:default]||{}), []
  end

  describe "#default=" do
    include_examples 'Vash::Hash#spec_method_with', {
      :method                   => :default=,
      :model_class              => _model_class,
      :hash_initializers        => [],
      :match_attributes         => [:default],
      :match_attributes_at_end  => [:default]
    }.merge(_params).merge(_params[:default=]||{}), [_missing_value]
  end

  describe "#default_proc" do
    include_examples 'Vash::Hash#spec_method_with', {
      :method                   => :default_proc,
      :model_class              => _model_class,
      :hash_initializers        => [],
    }.merge(_params).merge(_params[:default_proc]||{}), []
  end

  # for < 1.9 there is no way to set default_proc via instance methods.
  if ruby_version >= 0x010901
    include_examples 'Vash::Hash#spec_method_with', {
      :method                   => :default_proc=,
      :model_class              => _model_class,
      :hash_initializers        => [],
      :match_attributes         => [:default_proc],
      :match_attributes_at_end  => [:default_proc]
    }.merge(_params).merge(_params[:default_proc=]||{}), [proc {|h,k| _missing_value}]
  end

  describe "#values_at" do
    include_examples 'Vash::Hash#spec_method_with', {
      :method                   => :values_at,
      :model_class              => _model_class,
    }.merge(_params).merge(_params[:default_proc=]||{}),
    [], [_missing_key], [_existing_key], [_missing_key,_existing_key]
  end

end
