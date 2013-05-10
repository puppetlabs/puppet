require 'spec_helper'
require 'puppet/provider/aixobject'

describe Puppet::Provider::AixObject do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :name   => 'test_aix_user',
      :ensure => :present
    )
  end

  let(:provider) do
    provider = Puppet::Provider::AixObject.new resource
  end

  describe "base provider methods" do
    [ :lscmd,
      :addcmd,
      :modifycmd,
      :deletecmd
    ].each do |method|
      it "should raise an error when unimplemented method #{method} called" do
        lambda do
          provider.send(method)
        end.should raise_error(Puppet::Error, /not defined/)
      end
    end
  end
end