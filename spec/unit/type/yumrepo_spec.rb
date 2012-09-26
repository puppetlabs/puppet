#! /usr/bin/env ruby

require 'spec_helper'


describe Puppet::Type.type(:yumrepo) do
  include PuppetSpec::Files

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

  # these tests were ported from the old spec/unit/type/yumrepo_spec.rb, pretty much verbatim
  describe "When manipulating config file" do


    def make_repo(name, hash={})
      hash[:name] = name
      Puppet::Type.type(:yumrepo).new(hash)
    end

    def all_sections(inifile)
      sections = []
      inifile.each_section { |section| sections << section.name }
      sections.sort
    end

    def create_data_files()
      File.open(File.join(@yumdir, "fedora.repo"), "w") do |f|
        f.print(FEDORA_REPO_FILE)
      end

      File.open(File.join(@yumdir, "fedora-devel.repo"), "w") do |f|
        f.print(FEDORA_DEVEL_REPO_FILE)
      end
    end



    before(:each) do
      @yumdir = tmpdir("yumrepo_spec_tmpdir")
      @yumconf = File.join(@yumdir, "yum.conf")
      File.open(@yumconf, "w") do |f|
        f.print "[main]\nreposdir=#{@yumdir} /no/such/dir\n"
      end
      Puppet::Type.type(:yumrepo).yumconf = @yumconf

      # It needs to be reset each time, otherwise the cache is used.
      Puppet::Type.type(:yumrepo).inifile = nil
    end


    it "should be able to create a valid config file" do
      values = {
          :descr => "Fedora Core $releasever - $basearch - Base",
          :baseurl => "http://example.com/yum/$releasever/$basearch/os/",
          :enabled => "1",
          :gpgcheck => "1",
          :includepkgs => "absent",
          :gpgkey => "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora",
          :proxy => "http://proxy.example.com:80/",
          :proxy_username => "username",
          :proxy_password => "password"
      }
      repo = make_repo("base", values)


      catalog = Puppet::Resource::Catalog.new
      # Stop Puppet from doing a bunch of magic; might want to think about a util for specs that handles this
      catalog.host_config = false
      catalog.add_resource(repo)
      catalog.apply

      inifile = Puppet::Type.type(:yumrepo).read
      sections = all_sections(inifile)
      sections.should == ['base', 'main']
      text = inifile["base"].format
      text.should == EXPECTED_CONTENTS_FOR_CREATED_FILE
    end


    # Modify one existing section
    it "should be able to modify an existing config file" do

      create_data_files

      devel = make_repo("development", { :descr => "New description" })
      current_values = devel.retrieve

      devel[:name].should == "development"
      current_values[devel.property(:descr)].should == 'Fedora Core $releasever - Development Tree'
      devel.property(:descr).should == 'New description'

      catalog = Puppet::Resource::Catalog.new
      # Stop Puppet from doing a bunch of magic; might want to think about a util for specs that handles this
      catalog.host_config = false
      catalog.add_resource(devel)
      catalog.apply

      inifile = Puppet::Type.type(:yumrepo).read
      inifile['development']['name'].should == 'New description'
      inifile['base']['name'].should == 'Fedora Core $releasever - $basearch - Base'
      inifile['base']['exclude'].should == "foo\n  bar\n  baz"
      all_sections(inifile).should == ['base', 'development', 'main']
    end


    # Delete mirrorlist by setting it to :absent and enable baseurl
    it "should support 'absent' value" do
      create_data_files

      baseurl = 'http://example.com/'

      devel = make_repo(
          "development",
          { :mirrorlist => 'absent',

            :baseurl => baseurl })
      devel.retrieve

      catalog = Puppet::Resource::Catalog.new
      # Stop Puppet from doing a bunch of magic; might want to think about a util for specs that handles this
      catalog.host_config = false
      catalog.add_resource(devel)
      catalog.apply

      inifile = Puppet::Type.type(:yumrepo).read
      sec = inifile["development"]
      sec["mirrorlist"].should == nil
      sec["baseurl"].should == baseurl
    end


  end


end


EXPECTED_CONTENTS_FOR_CREATED_FILE = <<'EOF'
[base]
name=Fedora Core $releasever - $basearch - Base
baseurl=http://example.com/yum/$releasever/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora
proxy=http://proxy.example.com:80/
proxy_username=username
proxy_password=password
EOF


FEDORA_REPO_FILE = <<END
[base]
name=Fedora Core $releasever - $basearch - Base
mirrorlist=http://fedora.redhat.com/download/mirrors/fedora-core-$releasever
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora
exclude=foo
  bar
  baz
END

FEDORA_DEVEL_REPO_FILE = <<END
[development]
# These packages are untested and still under development. This
# repository is used for updates to test releases, and for
# development of new releases.
#
# This repository can see significant daily turn over and can see major
# functionality changes which cause unexpected problems with other
# development packages. Please use these packages if you want to work
# with the Fedora developers by testing these new development packages.
#
# fedora-test-list@redhat.com is available as a discussion forum for
# testing and troubleshooting for development packages in conjunction
# with new test releases.
#
# fedora-devel-list@redhat.com is available as a discussion forum for
# testing and troubleshooting for development packages in conjunction
# with developing new releases.
#
# Reportable issues should be filed at bugzilla.redhat.com
# Product: Fedora Core
# Version: devel
name=Fedora Core $releasever - Development Tree
#baseurl=http://download.fedora.redhat.com/pub/fedora/linux/core/development/$basearch/
mirrorlist=http://fedora.redhat.com/download/mirrors/fedora-core-rawhide
enabled=0
gpgcheck=0
END
