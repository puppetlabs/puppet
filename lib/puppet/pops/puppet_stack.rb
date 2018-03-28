module Puppet::Pops
# Module for making a call such that there is an identifiable entry on
# the ruby call stack enabling getting a puppet call stack
# To use this make a call with:
# ```
# Puppet::Pops::PuppetStack.stack(file, line, receiver, message, args)
# ```
# To get the stack call:
# ```
# Puppet::Pops::PuppetStack.stacktrace
#
# When getting a backtrace in Ruby, the puppet stack frames are
# identified as coming from "in 'stack'" and having a ".pp" file
# name.
# To support testing, a given file that is an empty string, or nil
# as well as a nil line number are supported. Such stack frames
# will be represented with the text `unknown` and `0´ respectively.
#
module PuppetStack
  # Pattern matching an entry in the ruby stack that is a puppet entry
  PP_ENTRY_PATTERN = /^(.*\.pp)?:([0-9]+):in (`stack'|`block in call_function')/

  # Sends a message to an obj such that it appears to come from
  # file, line when calling stacktrace.
  #
  def self.stack(file, line, obj, message, args, &block)
    file = '' if file.nil?
    line = 0 if line.nil?

    if block_given?
      Kernel.eval("obj.send(message, *args, &block)", Kernel.binding(), file, line)
    else
      Kernel.eval("obj.send(message, *args)", Kernel.binding(), file, line)
    end
  end

  def self.stacktrace
    caller().reduce([]) do |memo, loc|
      if loc =~ PP_ENTRY_PATTERN
        memo << [$1.nil? ? 'unknown' : $1, $2.to_i]
      end
      memo
    end
  end

  # Returns an Array with the top of the puppet stack, or an empty Array if there was no such entry.
  #
  def self.top_of_stack
    caller.each do |loc|
      if loc =~ PP_ENTRY_PATTERN
        return [$1.nil? ? 'unknown' : $1, $2.to_i]
      end
    end
    []
  end
end
end
