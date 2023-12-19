# frozen_string_literal: true

require_relative '../../../puppet/node/facts'
require_relative '../../../puppet/indirector/memory'

class Puppet::Node::Facts::Memory < Puppet::Indirector::Memory
  desc "Keep track of facts in memory but nowhere else.  This is used for
    one-time compiles, such as what the stand-alone `puppet` does.
    To use this terminus, you must load it with the data you want it
    to contain."
end
