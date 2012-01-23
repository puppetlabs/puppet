# The public name of this feature is 'face', but we have hidden all the
# plumbing over in the 'interfaces' namespace to make clear the distinction
# between the two.
#
# This file exists to ensure that the public name is usable without revealing
# the details of the implementation; you really only need go look at anything
# under Interfaces if you are looking to extend the implementation.
#
# It isn't hidden to gratuitously hide things, just to make it easier to
# separate out the interests people will have.  --daniel 2011-04-07
require 'puppet/interface'
Puppet::Face = Puppet::Interface

class Puppet::Face

  # We need special logging for Face commands that output to the console.
  # Errors and warnings should go to stderr, and all other messages should
  # go to stdout as is. This provides some flexability which allows us to
  # colorize messages with greater detail by calling the `colorize` method
  # on specific parts of a message:
  #
  #    "This message has a #{Puppet::Face.colorize(:cyan, 'cyan')} part"
  #
  # We also gain the ability to log warnings, errors, and notices to the
  # console using custom formatting and colors that enhance UX.
  #
  #    Puppet::Face.err "This will go to stderr with nice formatting"
  #
  extend Puppet::Util::Logging
  @@console = Puppet::Util::Log.desttypes[:console].new

  def self.colorize(color, msg)
    @@console.colorize(color, msg)
  end
end
