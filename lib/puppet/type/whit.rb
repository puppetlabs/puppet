Puppet::Type.newtype(:whit) do
  desc "The smallest possible resource type, for when you need a resource and naught else."

  newparam :name do
    desc "The name of the whit, because it must have one."
  end
end
