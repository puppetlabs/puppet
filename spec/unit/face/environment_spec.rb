#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

module PuppetFaceSpecs
describe Puppet::Face[:environment, '0.0.1'] do

  FS = Puppet::FileSystem

  before :each do
    Puppet[:environmentpath] = '/dev/null/environments'
  end

  let(:envdir) {
    FS::MemoryFile.a_directory(File.expand_path("/dev/null/environments"), [
      FS::MemoryFile.a_directory("manual", [
        FS::MemoryFile.a_regular_file_containing("environment.conf", <<-CONTENT),
        environment_timeout=manual
        modulepath=/dev/null/modpath
        CONTENT
      ], :ctime => 12345678),
      FS::MemoryFile.a_directory("unlimited", [
        FS::MemoryFile.a_regular_file_containing("environment.conf", <<-CONTENT),
        environment_timeout=unlimited
        modulepath=/dev/null/modpath
        CONTENT
      ], :ctime => 12345678),
      FS::MemoryFile.a_directory("timingout", [
        FS::MemoryFile.a_regular_file_containing("environment.conf", <<-CONTENT),
        environment_timeout=3m
        modulepath=/dev/null/modpath
        CONTENT
      ], :ctime => 12345678),
    ])
  }

  it "prints the list of environments" do
    FS.overlay(
      *envdir
    ) do
        expect { subject.list }.to have_printed(<<-OUTPUT)
manual
unlimited
timingout
        OUTPUT
    end
  end

  it "prints detailed list of environments" do
    FS.overlay(
      *envdir
    ) do
        expect { subject.list({:details => true}) }.to have_printed(<<-OUTPUT)
manual (timeout: manual, manifest: /dev/null/environments/manual/manifests, modulepath: /dev/null/modpath)
unlimited (timeout: unlimited, manifest: /dev/null/environments/unlimited/manifests, modulepath: /dev/null/modpath)
timingout (timeout: 3m, manifest: /dev/null/environments/timingout/manifests, modulepath: /dev/null/modpath)
        OUTPUT
    end
  end

  it "flushes an environment" do
    FS.overlay(
      *envdir
    ) do
      Puppet::FileSystem.stat('/dev/null/environments/manual').ctime.to_i.should_not be > 12345678
      subject.flush('manual')
      Puppet::FileSystem.stat('/dev/null/environments/manual').ctime.to_i.should be > 12345678
    end
  end

  it "flushes several environments" do
    FS.overlay(
      *envdir
    ) do
      Puppet::FileSystem.stat("/dev/null/environments/unlimited").ctime.to_i.should_not be > 12345678
      Puppet::FileSystem.stat("/dev/null/environments/manual").ctime.to_i.should_not be > 12345678
      subject.flush(%w{manual unlimited})
      Puppet::FileSystem.stat('/dev/null/environments/unlimited').ctime.to_i.should be > 12345678
      Puppet::FileSystem.stat('/dev/null/environments/manual').ctime.to_i.should be > 12345678
    end
  end

  it "flushes all environments" do
    FS.overlay(
      *envdir
    ) do
      subject.flush({:all => true})
      Puppet::FileSystem.stat('/dev/null/environments/manual').ctime.to_i.should be > 12345678
      Puppet::FileSystem.stat('/dev/null/environments/unlimited').ctime.to_i.should be > 12345678
      Puppet::FileSystem.stat('/dev/null/environments/timingout').ctime.to_i.should be > 12345678
    end
  end

end
end
