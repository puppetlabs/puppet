# (Documentation in 3.x stub)
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
