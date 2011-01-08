#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Type.type(:cron) do
  before do
    @class = Puppet::Type.type(:cron)

    # Init a fake provider
    @provider_class = stub 'provider_class', :ancestors => [], :name => 'fake', :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns @provider_class
    @class.stubs(:provider).returns @provider_class

    @provider = stub 'provider', :class => @provider_class, :clean => nil
    @provider.stubs(:is_a?).returns false
    @provider_class.stubs(:new).returns @provider

    @cron = @class.new( :name => "foo" )
  end

  it "it should accept an :environment that looks like a path" do
    lambda do
      @cron[:environment] = 'PATH=/bin:/usr/bin:/usr/sbin'
    end.should_not raise_error
  end

  it "should not accept environment variables that do not contain '='" do
    lambda do
      @cron[:environment] = "INVALID"
    end.should raise_error(Puppet::Error)
  end

  it "should accept empty environment variables that do not contain '='" do
    lambda do
      @cron[:environment] = "MAILTO="
    end.should_not raise_error(Puppet::Error)
  end

  it "should accept 'absent'" do
    lambda do
      @cron[:environment] = 'absent'
    end.should_not raise_error(Puppet::Error)
  end
end
