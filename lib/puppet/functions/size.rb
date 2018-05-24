# The same as length() - returns the size of an Array, Hash, String, or Binary value.
#
# @since 6.0.0 - also supporting Binary
#
Puppet::Functions.create_function(:size) do
  dispatch :generic_size do
    param 'Variant[Collection, String, Binary]', :arg
  end


  def generic_size(arg)
    call_function('length', arg)
  end

end
