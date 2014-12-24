# spec/unit/provider/package/up2date_spec.rb
require 'spec_helper'

describe 'up2date package provider' do

  # This sets the class itself as the subject rather than
  # an instance of the class.
  subject do
    Puppet::Type.type(:package).provider(:up2date)
  end

  osfamilies = [ 'redhat' ]
  releases = [ '2.1', '3', '4' ]

  osfamilies.each do |osfamily|
    releases.each do |release|
      it "should be the default provider on #{osfamily} #{release}" do
        Facter.expects(:value).with(:osfamily).returns(osfamily)
        Facter.expects(:value).with(:lsbdistrelease).returns(release)
        expect(subject.default?).to be_truthy
      end
    end
  end
end
