#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'

describe Puppet::Settings do
  include PuppetSpec::Files

  def minimal_default_settings
    { :noop => {:default => false, :desc => "noop"} }
  end

  def define_settings(section, settings_hash)
    settings.define_settings(section, minimal_default_settings.update(settings_hash))
  end

  let(:settings) { Puppet::Settings.new }

  it "should be able to make needed directories" do
    define_settings(:main,
      :maindir => {
          :default => tmpfile("main"),
          :type => :directory,
          :desc => "a",
      }
    )
    settings.use(:main)

    expect(File.directory?(settings[:maindir])).to be_truthy
  end

  it "should make its directories with the correct modes" do
    define_settings(:main,
        :maindir => {
            :default => tmpfile("main"),
            :type => :directory,
            :desc => "a",
            :mode => 0750
        }
    )

    settings.use(:main)

    expect(Puppet::FileSystem.stat(settings[:maindir]).mode & 007777).to eq(0750)
  end

  it "will properly parse a UTF-8 configuration file" do
    rune_utf8 = "\u16A0\u16C7\u16BB" # ᚠᛇᚻ
    config = tmpfile("config")
    define_settings(:main,
      :config => {
        :type => :file,
        :default => config,
        :desc => "a"
      },
      :environment => {
        :default => 'dingos',
        :desc => 'test',
      }
    )

    File.open(config, 'w') do |file|
      file.puts <<-EOF
[main]
environment=#{rune_utf8}
      EOF
    end

    settings.initialize_global_settings
    expect(settings[:environment]).to eq(rune_utf8)
  end

  it "reparses configuration if configuration file is touched", :if => !Puppet.features.microsoft_windows? do
    config = tmpfile("config")
    define_settings(:main,
      :config => {
        :type => :file,
        :default => config,
        :desc => "a"
      },
      :environment => {
        :default => 'dingos',
        :desc => 'test',
      }
    )

    Puppet[:filetimeout] = '1s'

    File.open(config, 'w') do |file|
      file.puts <<-EOF
[main]
environment=toast
      EOF
    end

    settings.initialize_global_settings
    expect(settings[:environment]).to eq('toast')

    # First reparse establishes WatchedFiles
    settings.reparse_config_files

    sleep 1

    File.open(config, 'w') do |file|
      file.puts <<-EOF
[main]
environment=bacon
      EOF
    end

    # Second reparse if later than filetimeout, reparses if changed
    settings.reparse_config_files
    expect(settings[:environment]).to eq('bacon')
  end
end
