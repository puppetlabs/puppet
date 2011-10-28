Puppet::Type.newtype(:whit) do
  desc "Whits are internal artifacts of Puppet's current implementation, and
    Puppet suppresses their appearance in all logs. We make no guarantee of
    the whit's continued existence, and it should never be used in an actual
    manifest. Use the `anchor` type from the puppetlabs-stdlib module if you
    need arbitrary whit-like no-op resources."

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
    #   chain of propagation.
  end
end
