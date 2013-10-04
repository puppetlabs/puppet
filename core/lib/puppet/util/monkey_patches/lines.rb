require 'puppet/util/monkey_patches'
require 'enumerator'

module Puppet::Util::MonkeyPatches::Lines
  def lines(separator = $/)
    if block_given?
      self.each_line(separator) {|line| yield line }
      return self
    else
      return enum_for(:each_line, separator)
    end
  end
end
