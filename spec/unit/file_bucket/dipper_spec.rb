#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'pathname'

require 'puppet/file_bucket/dipper'
describe Puppet::FileBucket::Dipper do
  include PuppetSpec::Files

  def make_tmp_file(contents)
    file = tmpfile("file_bucket_file")
    File.open(file, 'w') { |f| f.write(contents) }
    file
  end

  it "should fail in an informative way when there are failures backing up to the server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    file = make_tmp_file('contents')
    Puppet::FileBucket::File.any_instance.expects(:save).raises ArgumentError

    lambda { @dipper.backup(file) }.should raise_error(Puppet::Error)
  end

  it "should backup files to a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    file = make_tmp_file('my contents')
    checksum = Digest::MD5.hexdigest('my contents')

    Puppet::FileBucket::File.any_instance.expects(:save)
    @dipper.backup(file).should == checksum
  end

  it "should retrieve files from a local bucket" do
    @dipper = Puppet::FileBucket::Dipper.new(:Path => "/my/bucket")

    checksum = Digest::MD5.hexdigest('my contents')

    Puppet::FileBucket::File.expects(:find).with{|x,opts|
      x == "md5/#{checksum}"
    }.returns(Puppet::FileBucket::File.new('my contents'))

    @dipper.getfile(checksum).should == 'my contents'
  end

  it "should backup files to a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    file = make_tmp_file('my contents')
    checksum = Digest::MD5.hexdigest('my contents')

    real_path = Pathname.new(file).realpath

    Puppet::FileBucket::File.any_instance.expects(:save).with("https://puppetmaster:31337/production/file_bucket_file/md5/#{checksum}")

    @dipper.backup(file).should == checksum
  end

  it "should retrieve files from a remote server" do
    @dipper = Puppet::FileBucket::Dipper.new(:Server => "puppetmaster", :Port => "31337")

    checksum = Digest::MD5.hexdigest('my contents')

    Puppet::FileBucket::File.expects(:find).with{|x,opts|
      x == "https://puppetmaster:31337/production/file_bucket_file/md5/#{checksum}"
    }.returns(Puppet::FileBucket::File.new('my contents'))

    @dipper.getfile(checksum).should == "my contents"
  end
end
