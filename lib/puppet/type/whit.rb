Puppet::Type.newtype(:whit) do
  desc "The smallest possible resource type, for when you need a resource and naught else."

  newparam :name do
    desc "The name of the whit, because it must have one."
  end

  def to_s
    "(#{name})"
  end

  def refresh
    # We don't do anything with them, but we need this to
    #   show that we are "refresh aware" and not break the
    #   chain of propogation.
  end
end
