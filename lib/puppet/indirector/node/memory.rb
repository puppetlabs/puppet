require 'puppet/node'
require 'puppet/indirector/memory'

class Puppet::Node::Memory < Puppet::Indirector::Memory
  desc "Keep track of nodes in memory but nowhere else.  This is used for
    one-time compiles, such as what the stand-alone `puppet` does.
    To use this terminus, you must load it with the data you want it
    to contain; it is only useful for developers and should generally not
    be chosen by a normal user."
end
