#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:sshkey).provider(:parsed)

describe "sshkey parsed provider" do
  let :type do Puppet::Type.type(:sshkey) end
  let :provider do type.provider(:parsed) end
  subject { provider }

  after :each do
    subject.clear
  end

  def key
    'AAAAB3NzaC1yc2EAAAABIwAAAQEAzwHhxXvIrtfIwrudFqc8yQcIfMudrgpnuh1F3AV6d2BrLgu/yQE7W5UyJMUjfj427sQudRwKW45O0Jsnr33F4mUw+GIMlAAmp9g24/OcrTiB8ZUKIjoPy/cO4coxGi8/NECtRzpD/ZUPFh6OEpyOwJPMb7/EC2Az6Otw4StHdXUYw22zHazBcPFnv6zCgPx1hA7QlQDWTu4YcL0WmTYQCtMUb3FUqrcFtzGDD0ytosgwSd+JyN5vj5UwIABjnNOHPZ62EY1OFixnfqX/+dUwrFSs5tPgBF/KkC6R7tmbUfnBON6RrGEmu+ajOTOLy23qUZB4CQ53V7nyAWhzqSK+hw=='
  end

  it "should parse the name from the first field" do
    subject.parse_line('test ssh-rsa '+key)[:name].should == "test"
  end

  it "should parse the first component of the first field as the name" do
    subject.parse_line('test,alias ssh-rsa '+key)[:name].should == "test"
  end

  it "should parse host_aliases from the remaining components of the first field" do
    subject.parse_line('test,alias ssh-rsa '+key)[:host_aliases].should == ["alias"]
  end

  it "should parse multiple host_aliases" do
    subject.parse_line('test,alias1,alias2,alias3 ssh-rsa '+key)[:host_aliases].should == ["alias1","alias2","alias3"]
  end

  it "should not drop an empty host_alias" do
    subject.parse_line('test,alias, ssh-rsa '+key)[:host_aliases].should == ["alias",""]
  end

  it "should recognise when there are no host aliases" do
    subject.parse_line('test ssh-rsa '+key)[:host_aliases].should == []
  end

  context "with the sample file" do
    let :fixture do my_fixture('sample') end
    before :each do subject.stubs(:default_target).returns(fixture) end

    it "should parse to records on prefetch" do
      subject.target_records(fixture).should be_empty
      subject.prefetch

      records = subject.target_records(fixture)
      records.should be_an Array
      records.should be_all {|x| x.should be_an Hash }
    end

    it "should reconstitute the file from records" do
      subject.prefetch
      records = subject.target_records(fixture)

      text = subject.to_file(records).gsub(/^# HEADER.+\n/, '')

      oldlines = File.readlines(fixture).map(&:chomp)
      newlines = text.chomp.split("\n")
      oldlines.length.should == newlines.length

      oldlines.zip(newlines).each do |old, new|
        old.gsub(/\s+/, '').should == new.gsub(/\s+/, '')
      end
    end
  end
end
