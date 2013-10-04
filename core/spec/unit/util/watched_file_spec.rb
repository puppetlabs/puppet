require 'spec_helper'
require 'puppet/util/watched_file'
require 'puppet/util/watcher'

describe Puppet::Util::WatchedFile do
  let(:an_absurdly_long_timeout) { Puppet::Util::Watcher::Timer.new(100000) }
  let(:an_immediate_timeout) { Puppet::Util::Watcher::Timer.new(0) }

  it "acts like a string so that it can be used as a filename" do
    watched = Puppet::Util::WatchedFile.new("foo")

    expect(watched.to_str).to eq("foo")
  end

  it "considers the file to be unchanged before the timeout expires" do
    watched = Puppet::Util::WatchedFile.new(a_file_that_doesnt_exist, an_absurdly_long_timeout)

    expect(watched).to_not be_changed
  end

  it "considers a file that is created to be changed" do
    watched_filename = a_file_that_doesnt_exist
    watched = Puppet::Util::WatchedFile.new(watched_filename, an_immediate_timeout)

    create_file(watched_filename)

    expect(watched).to be_changed
  end

  it "considers a missing file to remain unchanged" do
    watched = Puppet::Util::WatchedFile.new(a_file_that_doesnt_exist, an_immediate_timeout)

    expect(watched).to_not be_changed
  end

  it "considers a file that has changed but the timeout is not expired to still be unchanged" do
    watched_filename = a_file_that_doesnt_exist
    watched = Puppet::Util::WatchedFile.new(watched_filename, an_absurdly_long_timeout)

    create_file(watched_filename)

    expect(watched).to_not be_changed
  end

  def create_file(name)
    File.open(name, "wb") { |file| file.puts("contents") }
  end

  def a_file_that_doesnt_exist
    PuppetSpec::Files.tmpfile("watched_file")
  end
end
