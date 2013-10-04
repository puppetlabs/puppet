require 'spec_helper'
require 'puppet/property/boolean'

describe Puppet::Property::Boolean do
  let (:resource) { mock('resource') }
  subject { described_class.new(:resource => resource) }

  [ true, :true, 'true', :yes, 'yes', 'TrUe', 'yEs' ].each do |arg|
    it "should munge #{arg.inspect} as true" do
      subject.munge(arg).should == true
    end
  end
  [ false, :false, 'false', :no, 'no', 'FaLSE', 'nO' ].each do |arg|
    it "should munge #{arg.inspect} as false" do
      subject.munge(arg).should == false
    end
  end
  [ nil, :undef, 'undef', '0', 0, '1', 1, 9284 ].each do |arg|
    it "should fail to munge #{arg.inspect}" do
      expect { subject.munge(arg) }.to raise_error Puppet::Error
    end
  end
end

