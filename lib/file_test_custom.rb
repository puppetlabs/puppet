module Puppet::FileTest
  class << self
    alias_method :exists?, :exist?
  end
end