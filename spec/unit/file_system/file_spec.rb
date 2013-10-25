require 'spec_helper'
require 'puppet/file_system'
require 'puppet/util/platform'

describe Puppet::FileSystem::File do
  include PuppetSpec::Files

  context "#exclusive_open" do
    it "opens ands allows updating of an existing file" do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "the contents"))

      file.exclusive_open(0660, 'r+') do |fh|
        old = fh.read
        fh.truncate(0)
        fh.rewind
        fh.write("updated #{old}")
      end

      expect(file.read).to eq("updated the contents")
    end

    it "opens, creates ands allows updating of a new file" do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      file.exclusive_open(0660, 'w') do |fh|
        fh.write("updated new file")
      end

      expect(file.read).to eq("updated new file")
    end

    it "excludes other processes from updating at the same time", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(file_containing("file_to_update", "0"))

      increment_counter_in_multiple_processes(file, 5, 'r+')

      expect(file.read).to eq("5")
    end

    it "excludes other processes from updating at the same time even when creating the file", :unless => Puppet::Util::Platform.windows? do
      file = Puppet::FileSystem::File.new(tmpfile("file_to_update"))

      increment_counter_in_multiple_processes(file, 5, 'a+')

      expect(file.read).to eq("5")
    end

    def increment_counter_in_multiple_processes(file, num_procs, options)
      children = []
      5.times do |number|
        children << Kernel.fork do
          file.exclusive_open(0660, options) do |fh|
            fh.rewind
            contents = (fh.read || 0).to_i
            fh.truncate(0)
            fh.rewind
            fh.write((contents + 1).to_s)
          end
          exit(0)
        end
      end

      children.each { |pid| Process.wait(pid) }
    end
  end
end
