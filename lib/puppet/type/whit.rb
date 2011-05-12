Puppet::Type.newtype(:whit) do
  desc "The smallest possible resource type, for when you need a resource and naught else."

  newparam :name do
    desc "The name of the whit, because it must have one."
  end


  # Hide the fact that we're a whit from logs
  def to_s
    name.sub(/^completed_|^admissible_/, "")
  end

  def path
    to_s
  end

  def refresh
    # We don't do anything with them, but we need this to
    #   show that we are "refresh aware" and not break the
    #   chain of propogation.
  end
end
