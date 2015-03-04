#! /usr/bin/env ruby
require 'spec_helper'

maillist = Puppet::Type.type(:maillist)

describe maillist do
  before do
    @provider_class = Puppet::Type.type(:maillist).provider(:mailman)

    @provider = stub 'provider', :class => @provider_class, :clear => nil
    @provider.stubs(:respond_to).with(:aliases).returns(true)

    @provider_class.stubs(:new).returns(@provider)

    Puppet::Type.type(:maillist).stubs(:defaultprovider).returns(@provider_class)

    @maillist = Puppet::Type.type(:maillist).new( :name => 'test' )

    @catalog = Puppet::Resource::Catalog.new
    @maillist.catalog = @catalog
  end

  it "should generate aliases unless they already exist" do
    # Mail List aliases are careful not to stomp on managed Mail Alias aliases

    # test1 is an unmanaged alias from /etc/aliases
    Puppet::Type.type(:mailalias).provider(:aliases).stubs(:target_object).returns( StringIO.new("test1: root\n") )

    # test2 is a managed alias from the manifest
    dupe = Puppet::Type.type(:mailalias).new( :name => 'test2' )
    @catalog.add_resource dupe

    @provider.stubs(:aliases).returns({"test1" => 'this will get included', "test2" => 'this will dropped', "test3" => 'this will get included'})

    generated = @maillist.generate
    expect(generated.map{ |x| x.name  }.sort).to eq(['test1', 'test3'])
    expect(generated.map{ |x| x.class }).to      eq([Puppet::Type::Mailalias, Puppet::Type::Mailalias])

  end

end
