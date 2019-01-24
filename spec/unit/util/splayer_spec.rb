require 'spec_helper'
require 'puppet/util/splayer'

describe Puppet::Util::Splayer do
  include Puppet::Util::Splayer

  let (:subject) { self }

  before do
    Puppet[:splay] = true
    Puppet[:splaylimit] = "10"
  end

  it "should do nothing if splay is disabled" do
    Puppet[:splay] = false
    expect(subject).not_to receive(:sleep)
    subject.splay
  end

  it "should do nothing if it has already splayed" do
    expect(subject).to receive(:splayed?).and_return(true)
    expect(subject).not_to receive(:sleep)
    subject.splay
  end

  it "should log that it is splaying" do
    allow(subject).to receive(:sleep)
    expect(Puppet).to receive(:info)
    subject.splay
  end

  it "should sleep for a random portion of the splaylimit plus 1" do
    Puppet[:splaylimit] = "50"
    expect(subject).to receive(:rand).with(51).and_return(10)
    expect(subject).to receive(:sleep).with(10)
    subject.splay
  end

  it "should mark that it has splayed" do
    allow(subject).to receive(:sleep)
    subject.splay
    expect(subject).to be_splayed
  end
end
