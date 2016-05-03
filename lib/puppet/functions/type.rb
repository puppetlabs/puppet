# Returns the data type of a given value with a given degree of generality.
#
# @example Using `type()`
#
# ~~~ puppet
# notice type(42) =~ Type[Integer]
# ~~~
#
# Would notice true
#
# By default, the best possible inference is made where all details are retained.
# This is good when the type is used for further type calculations but is overwhelmingly
# rich in information if it is used in a error message.
#
# The optional argument `inference_method` may be given as (from lowest to highest fidelity):
#
# * `generalized` - reduces to common type and drops size constraints
# * `reduced` - reduces to common type in collections
# * `detailed` - (default) all details about inferred types is retained
#
# @example Using `type()` with different qualities:
#
# ~~~ puppet
# notice type([3.14, 42], generalized)
# notice type([3.14, 42], reduced)
# notice type([3.14, 42], detailed)
# notice type([3.14, 42])
# ~~~
#
# Would notice the four values:
#
# 1. 'Array[Numeric]'
# 2. 'Array[Numeric, 2, 2]'
# 3. 'Tuple[Float[3.14], Integer[42,42]]]'
# 4. 'Tuple[Float[3.14], Integer[42,42]]]'
#
# @param value [Any] - the value for which data type is returned
# @param inference_type[Enum[generalized, reduced, detailed]] inference_type
# @returns [Type] - the inferred type
#
# @since 4.4.0
#
Puppet::Functions.create_function(:type) do
  dispatch :type_detailed do
    param 'Any', :value
    optional_param 'Enum[detailed]', :inference_method
  end

  dispatch :type_parameterized do
    param 'Any', :value
    param 'Enum[reduced]', :inference_method
  end

  dispatch :type_generalized do
    param 'Any', :value
    param 'Enum[generalized]', :inference_method
  end

  def type_detailed(value, _ = nil)
    Puppet::Pops::Types::TypeCalculator.infer_set(value)
  end

  def type_parameterized(value, _)
    Puppet::Pops::Types::TypeCalculator.infer(value)
  end

  def type_generalized(value, _)
    Puppet::Pops::Types::TypeCalculator.infer(value).generalize
  end
end
