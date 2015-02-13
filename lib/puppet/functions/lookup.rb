# @see lib/puppet/parser/functions/lookup.rb for documentation
# TODO: Move docs here when the format has been determined.
#
Puppet::Functions.create_function(:lookup, Puppet::Functions::InternalFunction) do
  name_t = 'Variant[String,Array[String]]'
  value_type_t = 'Optional[Variant[String,Type]]'
  default_value_t = 'Any'
  accept_undef_t = 'Boolean'
  override_t = 'Hash[String,Any]'
  extra_t = 'Hash[String,Any]'
  merge_t = 'Variant[String[1],Hash[String,Scalar]]'
  block_t = "Callable[#{name_t}]"
  option_pairs =
      "value_type=>#{value_type_t},"\
      "default_value=>Optional[#{default_value_t}],"\
      "accept_undef=>Optional[#{accept_undef_t}],"\
      "override=>Optional[#{override_t}],"\
      "extra=>Optional[#{extra_t}],"\
      "merge=>Optional[#{merge_t}]"\

  dispatch :lookup_1 do
    scope_param
    param name_t, :name
    param value_type_t, :value_type
    param default_value_t, :default_value
    param merge_t, :merge
    arg_count(1, 4)
  end

  dispatch :lookup_2 do
    scope_param
    param name_t, :name
    param value_type_t, :value_type
    param merge_t, :merge
    arg_count(1, 3)
    required_block_param block_t, :block
  end

  # Lookup without name. Name then becomes a required entry in the options hash
  dispatch :lookup_3 do
    scope_param
    param "Struct[{name=>#{name_t},#{option_pairs}}]", :options_hash
    optional_block_param block_t, :block
  end

  # Lookup using name and options hash.
  dispatch :lookup_4 do
    scope_param
    param 'Variant[String,Array[String]]', :name
    param "Struct[{#{option_pairs}}]", :options_hash
    optional_block_param block_t, :block
  end

  def lookup_1(scope, name, value_type=nil, default_value=nil, merge=nil)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, value_type, default_value, false, {}, {}, merge)
  end

  def lookup_2(scope, name, value_type=nil, merge=nil, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, value_type, nil, false, {}, {}, merge, &block)
  end

  def lookup_3(scope, options_hash, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, options_hash['name'], *hash_args(options_hash), &block)
  end

  def lookup_4(scope, name, options_hash, &block)
    Puppet::Pops::Binder::Lookup.lookup(scope, name, *hash_args(options_hash), &block)
  end

  def hash_args(options_hash)
    [
        options_hash['value_type'],
        options_hash['default_value'],
        options_hash['accept_undef'] || false,
        options_hash['override'] || {},
        options_hash['extra'] || {},
        options_hash['merge']
    ]
  end
end
