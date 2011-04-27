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
end
