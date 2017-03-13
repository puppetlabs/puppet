# Handle splay options (sleeping for a random interval before executing)
module Puppet::Util::Splayer
  # Have we splayed already?
  def splayed?
    !!@splayed
  end

  # Sleep when splay is enabled; else just return.
  def splay(do_splay = Puppet[:splay])
    return unless do_splay
    return if splayed?

    time = rand(Puppet[:splaylimit] + 1)
    Puppet.info _("Sleeping for %{time} seconds (splay is enabled)") % { time: time }
    sleep(time)
    @splayed = true
  end
end
