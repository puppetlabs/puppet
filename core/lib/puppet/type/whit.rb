Puppet::Type.newtype(:whit) do
  desc "Whits are internal artifacts of Puppet's current implementation, and
    Puppet suppresses their appearance in all logs. We make no guarantee of
    the whit's continued existence, and it should never be used in an actual
    manifest. Use the `anchor` type from the puppetlabs-stdlib module if you
    need arbitrary whit-like no-op resources."

  newparam :name do
    desc "The name of the whit, because it must have one."
  end


  # Hide the fact that we're a whit from logs.
  #
  # I hate you, milkman whit.  You are so painful, so often.
  #
  # In this case the memoized version means we generate a new string about 1.9
  # percent of the time, and we allocate about 1.6MB less memory, and generate
  # a whole lot less GC churn.
  #
  # That number probably goes up at least O(n) with the complexity of your
  # catalog, and I suspect beyond that, because that is, like, 10,000 calls
  # for 200 distinct objects.  Even with just linear, that is a constant
  # factor of, like, 50n. --daniel 2012-07-17
  def to_s
    @to_s ||= name.sub(/^completed_|^admissible_/, "")
  end
  alias path to_s

  def refresh
    # We don't do anything with them, but we need this to show that we are
    # "refresh aware" and not break the chain of propagation.
  end
end
