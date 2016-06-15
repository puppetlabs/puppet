# Reverses the order of the elements of something that is iterable.
# (Documentation in 3.x stub)
#
# @since 4.4.0
#
Puppet::Functions.create_function(:reverse_each) do
  dispatch :reverse_each do
    param 'Iterable', :iterable
  end

  dispatch :reverse_each_block do
    param 'Iterable', :iterable
    block_param 'Callable[1,1]', :block
  end

  def reverse_each(iterable)
    # produces an Iterable
    Puppet::Pops::Types::Iterable.asserted_iterable(self, iterable).reverse_each
  end

  def reverse_each_block(iterable, &block)
    Puppet::Pops::Types::Iterable.asserted_iterable(self, iterable).reverse_each(&block)
    nil
  end
end
