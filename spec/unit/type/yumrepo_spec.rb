require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:yumrepo) do
  let(:yumrepo) {
    Puppet::Type.type(:yumrepo).new(
      :name => "puppetlabs"
    )
  }

  describe "When validating attributes" do
    it "should have a 'name' parameter'" do
      yumrepo[:name].should == "puppetlabs"
    end

    [:baseurl, :cost, :descr, :enabled, :enablegroups, :exclude, :failovermethod,
     :gpgcheck, :repo_gpgcheck, :gpgkey, :http_caching, :include, :includepkgs, :keepalive,
     :metadata_expire, :mirrorlist, :priority, :protect, :proxy, :proxy_username,
     :proxy_password, :timeout, :sslcacert, :sslverify, :sslclientcert,
     :sslclientkey, :s3_enabled, :metalink].each do |param|
      it "should have a '#{param}' parameter" do
        Puppet::Type.type(:yumrepo).attrtype(param).should == :property
      end
    end
  end

  describe "When validating attribute values" do
    [:cost, :enabled, :enablegroups, :failovermethod, :gpgcheck, :repo_gpgcheck, :http_caching,
     :keepalive, :metadata_expire, :priority, :protect, :timeout].each do |param|
      it "should support :absent as a value to '#{param}' parameter" do
        Puppet::Type.type(:yumrepo).new(:name => 'puppetlabs', param => :absent)
      end
    end

    [:cost, :enabled, :enablegroups, :gpgcheck, :repo_gpgcheck, :keepalive, :metadata_expire,
     :priority, :protect, :timeout].each do |param|
      it "should fail if '#{param}' is not true/false, 0/1, or yes/no" do
        expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "notanumber") }.to raise_error
      end
    end

    [:enabled, :enabledgroups, :gpgcheck, :repo_gpgcheck, :keepalive, :protect, :s3_enabled].each do |param|
      it "should fail if '#{param}' does not have one of the following values (0|1)" do
        expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "2") }.to raise_error
      end
    end

    it "should fail if 'failovermethod' does not have one of the following values (roundrobin|priority)" do
      expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :failovermethod => "notavalidvalue") }.to raise_error
    end

    it "should fail if 'http_caching' does not have one of the following values (packages|all|none)" do
      expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :http_caching => "notavalidvalue") }.to raise_error
    end

    it "should fail if 'sslverify' does not have one of the following values (True|False)" do
      expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "notavalidvalue") }.to raise_error
    end

    it "should succeed if 'sslverify' has one of the following values (True|False)" do
      Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "True")[:sslverify].should == "True"
      Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", :sslverify => "False")[:sslverify].should == "False"
    end

    [:mirrorlist, :baseurl, :gpgkey, :include, :proxy, :metalink].each do |param|
      it "should succeed if '#{param}' uses one of the following protocols (file|http|https|ftp)" do
        Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "file:///srv/example/")[param].should =~ %r{\Afile://}
        Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "http://example.com/")[param].should =~ %r{\Ahttp://}
        Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "https://example.com/")[param].should =~ %r{\Ahttps://}
        Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "ftp://example.com/")[param].should =~ %r{\Aftp://}
      end

      it "should fail if '#{param}' does not use one of the following protocols (file|http|https|ftp)" do
        expect { Puppet::Type.type(:yumrepo).new(:name => "puppetlabs", param => "gopher://example.com/") }.to raise_error
      end
    end
  end
end
