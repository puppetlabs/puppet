#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/file_locking'

describe Puppet::Util::FileLocking, :'fails_on_ruby_1.9.2' => true do
  before :each do
    @file = Tempfile.new("puppetspec")
    filepath = @file.path
    @file.close!()
    @file = filepath
    @data = {:a => :b, :c => "A string", :d => "another string", :e => %w{an array of strings}}
    File.open(@file, "w") { |f| f.puts YAML.dump(@data) }
  end

  it "should be able to keep file corruption from happening when there are multiple writers threads" do
    threads = []
    sync = Sync.new
    9.times { |a|
      threads << Thread.new {
        9.times { |b|
          sync.synchronize(Sync::SH) {
            Puppet::Util::FileLocking.readlock(@file) { |f|
              YAML.load(f.read).should == @data
            }
          }
          sleep 0.01
          sync.synchronize(Sync::EX) {
            Puppet::Util::FileLocking.writelock(@file) { |f|
              f.puts YAML.dump(@data)
            }
          }
        }
      }
    }
    threads.each { |th| th.join }
  end

  it "should be able to keep file corruption from happening when there are multiple writers processes" do
    unless Process.fork
      50.times { |b|
        Puppet::Util::FileLocking.writelock(@file) { |f|
          f.puts YAML.dump(@data)
        }
        sleep 0.01
      }
      Kernel.exit!
    end

    50.times { |c|
      Puppet::Util::FileLocking.readlock(@file) { |f|
        YAML.load(f.read).should == @data
      }
    }
  end
end
