#!/usr/bin/env rspec

require 'spec_helper'

describe Puppet::Type.type(:yumrepo) do

  describe "When validating attributes" do

    it "should have a 'name' parameter'" do
      Puppet::Type.type(:yumrepo).new(:name => "puppetlabs")[:name].should == "puppetlabs"
    end

    [:baseurl, :cost, :descr, :enabled, :enablegroups, :exclude, :failovermethod, :gpgcheck, :gpgkey, :http_caching, 
       :include, :includepkgs, :keepalive, :metadata_expire, :mirrorlist, :priority, :protect, :proxy, :proxy_username, :proxy_password, :timeout, 
       :sslcacert, :sslverify, :sslclientcert, :sslclientkey].each do |param|
      it "should have a '#{param}' parameter" do
        Puppet::Type.type(:yumrepo).attrtype(param).should == :property
     end
    end

  end

  describe "When validating attribute values" do
    
    [:cost, :enabled, :enablegroups, :failovermethod, :gpgcheck, :http_caching, :keepalive, :metadata_expire, :priority, :protect, :timeout].each do |param|
      it "should support :absent as a value to '#{param}' parameter" do
        Puppet::Type.type(:yumrepo).new(:name => "puppetlabs.repo", param => :absent)
     end
    end

    [:cost, :enabled, :enablegroups, :gpgcheck, :keepalive, :metadata_expire, :priority, :protect, :timeout].each do |param|
      it "should fail if '#{param}' is not a number" do
        lambda { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "notanumber") }.should raise_error
     end
    end

    [:enabled, :enabledgroups, :gpgcheck, :keepalive, :protect].each do |param|
      it "should fail if '#{param}' does not have one of the following values (0|1)" do
        lambda { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "2") }.should raise_error
      end
    end
    
    it "should fail if 'failovermethod' does not have one of the following values (roundrobin|priority)" do
      lambda { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :failovermethod => "notavalidvalue") }.should raise_error
    end

    it "should fail if 'http_caching' does not have one of the following values (packages|all|none)" do
      lambda { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :http_caching => "notavalidvalue") }.should raise_error
    end

    it "should fail if 'sslverify' does not have one of the following values (True|False)" do
      lambda { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "notavalidvalue") }.should raise_error
    end

    it "should succeed if 'sslverify' has one of the following values (True|False)" do
      Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "True")[:sslverify].should == "True"
      Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "False")[:sslverify].should == "False"
    end

  end

end
