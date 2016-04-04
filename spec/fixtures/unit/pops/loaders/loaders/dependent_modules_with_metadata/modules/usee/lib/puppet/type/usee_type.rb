Puppet::Type.newtype(:usee_type) do
  newparam(:name, :namevar => true) do
    desc 'An arbitrary name used as the identity of the resource.'
  end
end
