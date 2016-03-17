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
    expect(subject.parse_line('test ssh-rsa '+key)[:name]).to eq("test")
  end

  it "should parse the first component of the first field as the name" do
    expect(subject.parse_line('test,alias ssh-rsa '+key)[:name]).to eq("test")
  end

  it "should parse host_aliases from the remaining components of the first field" do
    expect(subject.parse_line('test,alias ssh-rsa '+key)[:host_aliases]).to eq(["alias"])
  end

  it "should parse multiple host_aliases" do
    expect(subject.parse_line('test,alias1,alias2,alias3 ssh-rsa '+key)[:host_aliases]).to eq(["alias1","alias2","alias3"])
  end

  it "should not drop an empty host_alias" do
    expect(subject.parse_line('test,alias, ssh-rsa '+key)[:host_aliases]).to eq(["alias",""])
  end

  it "should recognise when there are no host aliases" do
    expect(subject.parse_line('test ssh-rsa '+key)[:host_aliases]).to eq([])
  end

  context "with the sample file" do
    ['sample', 'sample_with_blank_lines'].each do |sample_file|
      let :fixture do my_fixture(sample_file) end
      before :each do subject.stubs(:default_target).returns(fixture) end

      it "should parse to records on prefetch" do
        expect(subject.target_records(fixture)).to be_empty
        subject.prefetch

        records = subject.target_records(fixture)
        expect(records).to be_an Array
        expect(records).to be_all {|x| expect(x).to be_an Hash }
      end

      it "should reconstitute the file from records" do
        subject.prefetch
        records = subject.target_records(fixture)
        text = subject.to_file(records).gsub(/^# HEADER.+\n/, '')

        oldlines = File.readlines(fixture).map(&:chomp)
        newlines = text.chomp.split("\n")
        expect(oldlines.length).to eq(newlines.length)

        oldlines.zip(newlines).each do |old, new|
          expect(old.gsub(/\s+/, '')).to eq(new.gsub(/\s+/, ''))
        end
      end
    end
  end

  context 'default ssh_known_hosts target path' do
    ['9.10', '9.11', '10.10'].each do |version|
      it 'should be `/etc/ssh_known_hosts` when OSX version 10.10 or older`' do
        Facter.expects(:value).with(:operatingsystem).returns('Darwin')
        Facter.expects(:value).with(:macosx_productversion_major).returns(version)
        expect(subject.default_target).to eq('/etc/ssh_known_hosts')
      end
    end

    ['10.11', '10.13', '11.0', '11.11'].each do |version|
      it 'should be `/etc/ssh/ssh_known_hosts` when OSX version 10.11 or newer`' do
        Facter.expects(:value).with(:operatingsystem).returns('Darwin')
        Facter.expects(:value).with(:macosx_productversion_major).returns(version)
        expect(subject.default_target).to eq('/etc/ssh/ssh_known_hosts')
      end
    end

    it 'should be `/etc/ssh/ssh_known_hosts` on other operating systems' do
      Facter.expects(:value).with(:operatingsystem).returns('RedHat')
      expect(subject.default_target).to eq('/etc/ssh/ssh_known_hosts')
    end
  end
end
