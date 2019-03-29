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
        allow(Facter).to receive(:value).with(:osfamily).and_return(osfamily)
        allow(Facter).to receive(:value).with(:lsbdistrelease).and_return(release)
        expect(subject.default?).to be_truthy
      end
    end
  end
end
