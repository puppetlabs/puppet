#!/usr/bin/env rspec
require 'spec_helper'

ssh_authorized_key = Puppet::Type.type(:ssh_authorized_key)

describe ssh_authorized_key, :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  before do
    @class = Puppet::Type.type(:ssh_authorized_key)

    @provider_class = stub 'provider_class', :name => "fake", :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns(@provider_class)
    @class.stubs(:provider).returns(@provider_class)

    @provider = stub 'provider', :class => @provider_class, :file_path => make_absolute("/tmp/whatever"), :clear => nil
    @provider_class.stubs(:new).returns(@provider)
    @catalog = Puppet::Resource::Catalog.new
  end

  it "should have :name be its namevar" do
    @class.key_attributes.should == [:name]
  end

  describe "when validating attributes" do

    [:name, :provider].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:type, :key, :user, :target, :options, :ensure].each do |property|
      it "should have a #{property} property" do
        @class.attrtype(property).should == :property
      end
    end

  end

  describe "when validating values" do

    describe "for name" do

      it "should support valid names" do
        proc { @class.new(:name => "username", :ensure => :present, :user => "nobody") }.should_not raise_error
        proc { @class.new(:name => "username@hostname", :ensure => :present, :user => "nobody") }.should_not raise_error
      end

      it "should support whitespace" do
        proc { @class.new(:name => "my test", :ensure => :present, :user => "nobody") }.should_not raise_error
      end

    end

    describe "for ensure" do

      it "should support :present" do
        proc { @class.new(:name => "whev", :ensure => :present, :user => "nobody") }.should_not raise_error
      end

      it "should support :absent" do
        proc { @class.new(:name => "whev", :ensure => :absent, :user => "nobody") }.should_not raise_error
      end

      it "should not support other values" do
        proc { @class.new(:name => "whev", :ensure => :foo, :user => "nobody") }.should raise_error(Puppet::Error, /Invalid value/)
      end

    end

    describe "for type" do


      it "should support ssh-dss" do
        proc { @class.new(:name => "whev", :type => "ssh-dss", :user => "nobody") }.should_not raise_error
      end

      it "should support ssh-rsa" do
        proc { @class.new(:name => "whev", :type => "ssh-rsa", :user => "nobody") }.should_not raise_error
      end

      it "should support :dsa" do
        proc { @class.new(:name => "whev", :type => :dsa, :user => "nobody") }.should_not raise_error
      end

      it "should support :rsa" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody") }.should_not raise_error
      end

      it "should alias :rsa to :ssh-rsa" do
        key = @class.new(:name => "whev", :type => :rsa, :user => "nobody")
        key.should(:type).should == :'ssh-rsa'
      end

      it "should alias :dsa to :ssh-dss" do
        key = @class.new(:name => "whev", :type => :dsa, :user => "nobody")
        key.should(:type).should == :'ssh-dss'
      end

      it "should not support values other than ssh-dss, ssh-rsa, dsa, rsa" do
        proc { @class.new(:name => "whev", :type => :something) }.should raise_error(Puppet::Error,/Invalid value/)
      end

    end

    describe "for key" do

      it "should support a valid key like a 1024 bit rsa key" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :key => 'AAAAB3NzaC1yc2EAAAADAQABAAAAgQDCPfzW2ry7XvMc6E5Kj2e5fF/YofhKEvsNMUogR3PGL/HCIcBlsEjKisrY0aYgD8Ikp7ZidpXLbz5dBsmPy8hJiBWs5px9ZQrB/EOQAwXljvj69EyhEoGawmxQMtYw+OAIKHLJYRuk1QiHAMHLp5piqem8ZCV2mLb9AsJ6f7zUVw==')}.should_not raise_error
      end

      it "should support a valid key like a 4096 bit rsa key" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :key => 'AAAAB3NzaC1yc2EAAAADAQABAAACAQDEY4pZFyzSfRc9wVWI3DfkgT/EL033UZm/7x1M+d+lBD00qcpkZ6CPT7lD3Z+vylQlJ5S8Wcw6C5Smt6okZWY2WXA9RCjNJMIHQbJAzwuQwgnwU/1VMy9YPp0tNVslg0sUUgpXb13WW4mYhwxyGmIVLJnUrjrQmIFhtfHsJAH8ZVqCWaxKgzUoC/YIu1u1ScH93lEdoBPLlwm6J0aiM7KWXRb7Oq1nEDZtug1zpX5lhgkQWrs0BwceqpUbY+n9sqeHU5e7DCyX/yEIzoPRW2fe2Gx1Iq6JKM/5NNlFfaW8rGxh3Z3S1NpzPHTRjw8js3IeGiV+OPFoaTtM1LsWgPDSBlzIdyTbSQR7gKh0qWYCNV/7qILEfa0yIFB5wIo4667iSPZw2pNgESVtenm8uXyoJdk8iWQ4mecdoposV/znknNb2GPgH+n/2vme4btZ0Sl1A6rev22GQjVgbWOn8zaDglJ2vgCN1UAwmq41RXprPxENGeLnWQppTnibhsngu0VFllZR5kvSIMlekLRSOFLFt92vfd+tk9hZIiKm9exxcbVCGGQPsf6dZ27rTOmg0xM2Sm4J6RRKuz79HQgA4Eg18+bqRP7j/itb89DmtXEtoZFAsEJw8IgIfeGGDtHTkfAlAC92mtK8byeaxGq57XCTKbO/r5gcOMElZHy1AcB8kw==')}.should_not raise_error
      end

      it "should support a valid key like a 1024 bit dsa key" do
        proc { @class.new(:name => "whev", :type => :dsa, :user => "nobody", :key => 'AAAAB3NzaC1kc3MAAACBAI80iR78QCgpO4WabVqHHdEDigOjUEHwIjYHIubR/7u7DYrXY+e+TUmZ0CVGkiwB/0yLHK5dix3Y/bpj8ZiWCIhFeunnXccOdE4rq5sT2V3l1p6WP33RpyVYbLmeuHHl5VQ1CecMlca24nHhKpfh6TO/FIwkMjghHBfJIhXK+0w/AAAAFQDYzLupuMY5uz+GVrcP+Kgd8YqMmwAAAIB3SVN71whLWjFPNTqGyyIlMy50624UfNOaH4REwO+Of3wm/cE6eP8n75vzTwQGBpJX3BPaBGW1S1Zp/DpTOxhCSAwZzAwyf4WgW7YyAOdxN3EwTDJZeyiyjWMAOjW9/AOWt9gtKg0kqaylbMHD4kfiIhBzo31ZY81twUzAfN7angAAAIBfva8sTSDUGKsWWIXkdbVdvM4X14K4gFdy0ZJVzaVOtZ6alysW6UQypnsl6jfnbKvsZ0tFgvcX/CPyqNY/gMR9lyh/TCZ4XQcbqeqYPuceGehz+jL5vArfqsW2fJYFzgCcklmr/VxtP5h6J/T0c9YcDgc/xIfWdZAlznOnphI/FA==')}.should_not raise_error
      end

      it "should not support whitespaces" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :key => 'AAA FA==')}.should raise_error(Puppet::Error,/Key must not contain whitespace/)
      end

    end

    describe "for options" do

      it "should support flags as options" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'cert-authority')}.should_not raise_error
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'no-port-forwarding')}.should_not raise_error
      end

      it "should support key-value pairs as options" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'command="command"')}.should_not raise_error
      end

      it "should support key-value pairs where value consist of multiple items" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'from="*.domain1,host1.domain2"')}.should_not raise_error
      end

      it "should support environments as options" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'environment="NAME=value"')}.should_not raise_error
      end

      it "should support multiple options as an array" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => ['cert-authority','environment="NAME=value"'])}.should_not raise_error
      end

      it "should not support a comma separated list" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => 'cert-authority,no-port-forwarding')}.should raise_error(Puppet::Error, /must be provided as an array/)
      end

      it "should use :absent as a default value" do
        @class.new(:name => "whev", :type => :rsa, :user => "nobody").should(:options).should == [:absent]
      end

      it "property should return well formed string of arrays from is_to_s" do
        resource = @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => ["a","b","c"])
        resource.property(:options).is_to_s(["a","b","c"]).should == "a,b,c"
      end

      it "property should return well formed string of arrays from should_to_s" do
        resource = @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => ["a","b","c"])
        resource.property(:options).should_to_s(["a","b","c"]).should == "a,b,c"
      end

    end

    describe "for user" do

      it "should support present users" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "root") }.should_not raise_error
      end

      it "should support absent users" do
        proc { @class.new(:name => "whev", :type => :rsa, :user => "ihopeimabsent") }.should_not raise_error
      end

    end

    describe "for target" do

      it "should support absolute paths" do
        proc { @class.new(:name => "whev", :type => :rsa, :target => "/tmp/here") }.should_not raise_error
      end

      it "should use the user's path if not explicitly specified" do
        @class.new(:name => "whev", :user => 'root').should(:target).should == File.expand_path("~root/.ssh/authorized_keys")
      end

      it "should not consider the user's path if explicitly specified" do
        @class.new(:name => "whev", :user => 'root', :target => '/tmp/here').should(:target).should == '/tmp/here'
      end

      it "should inform about an absent user" do
        Puppet::Log.level = :debug
        @class.new(:name => "whev", :user => 'idontexist').should(:target)
        @logs.map(&:message).should include("The required user is not yet present on the system")
      end

    end

  end

  describe "when neither user nor target is specified" do

    it "should raise an error" do
      proc do
        @class.new(
          :name   => "Test",
          :key    => "AAA",
          :type   => "ssh-rsa",
          :ensure => :present)
      end.should raise_error(Puppet::Error,/user.*or.*target.*mandatory/)
    end

  end

  describe "when both target and user are specified" do

    it "should use target" do
      resource = @class.new(
        :name => "Test",
        :user => "root",
        :target => "/tmp/blah"
      )
      resource.should(:target).should == "/tmp/blah"
    end

  end


  describe "when user is specified" do

    it "should determine target" do
      resource = @class.create(
        :name   => "Test",
        :user   => "root"
      )
      target = File.expand_path("~root/.ssh/authorized_keys")
      resource.should(:target).should == target
    end

    # Bug #2124 - ssh_authorized_key always changes target if target is not defined
    it "should not raise spurious change events" do
      resource = @class.new(:name => "Test", :user => "root")
      target = File.expand_path("~root/.ssh/authorized_keys")
      resource.property(:target).safe_insync?(target).should == true
    end

  end

  describe "when calling validate" do

    it "should not crash on a non-existant user" do
      resource = @class.create(
        :name   => "Test",
        :user   => "ihopesuchuserdoesnotexist"
      )
      proc { resource.validate }.should_not raise_error
    end

  end

end
