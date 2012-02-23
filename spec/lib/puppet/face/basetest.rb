require 'puppet/face'

Puppet::Face.define(:basetest, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"
  summary "This is just so tests don't fail"

  option "--[no-]boolean"
  option "--mandatory ARGUMENT"

  action :foo do
    option("--action")
    when_invoked do |*args| args.length end
  end

  action :return_true do
    summary "just returns true"
    when_invoked do |options| true end
  end

  action :return_false do
    summary "just returns false"
    when_invoked do |options| false end
  end

  action :return_nil do
    summary "just returns nil"
    when_invoked do |options| nil end
  end

  action :raise do
    summary "just raises an exception"
    when_invoked do |options| raise ArgumentError, "your failure" end
  end

  action :with_s_rendering_hook do
    summary "has a rendering hook for 's'"
    when_invoked do |options| "this is not the hook you are looking for" end
    when_rendering :s do |value| "you invoked the 's' rendering hook" end
  end

  action :count_args do
    summary "return the count of arguments given"
    when_invoked do |*args| args.length - 1 end
  end

  action :with_specific_exit_code do
    summary "just call exit with the desired exit code"
    when_invoked do |options| exit(5) end
  end
end
