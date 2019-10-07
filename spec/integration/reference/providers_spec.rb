require 'spec_helper'

require 'puppet/util/reference'

reference = Puppet::Util::Reference.reference(:providers)

describe reference do
  it "should exist" do
    expect(reference).not_to be_nil
  end

  it "should be able to be rendered as markdown" do
    # We have a :confine block that calls execute in our upstart provider, which fails
    # on jruby. Thus, we stub it out here since we don't care to do any assertions on it.
    # This is only an issue if you're running these unit tests on a platform where upstart
    # is a default provider, like Ubuntu trusty.
    allow(Puppet::Util::Execution).to receive(:execute)

    reference.to_markdown
  end
end
