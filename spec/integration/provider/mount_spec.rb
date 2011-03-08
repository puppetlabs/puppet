require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_bucket/dipper'

describe "mount provider (integration)" do
  include PuppetSpec::Files

  def create_fake_fstab(initially_contains_entry)
    File.open(@fake_fstab, 'w') do |f|
      if initially_contains_entry
        f.puts("/dev/disk1s1\t/Volumes/foo_disk\tmsdos\tlocal\t0\t0")
      end
    end
  end

  before :each do
    @fake_fstab = tmpfile('fstab')
    @current_options = "local"
    Puppet::Type.type(:mount).defaultprovider.stubs(:default_target).returns(@fake_fstab)
    Facter.stubs(:value).with(:operatingsystem).returns('Darwin')
    Puppet::Util::ExecutionStub.set do |command, options|
      case command[0]
      when %r{/s?bin/mount}
        if command.length == 1
          if @mounted
            "/dev/disk1s1 on /Volumes/foo_disk (msdos, #{@current_options})\n"
          else
            ''
          end
        else
          command.length.should == 4
          command[1].should == '-o'
          command[3].should == '/Volumes/foo_disk'
          @mounted.should == false # verify that we don't try to call "mount" redundantly
          @current_options = command[2]
          check_fstab(true)
          @mounted = true
          ''
        end
      when %r{/s?bin/umount}
        command.length.should == 2
        command[1].should == '/Volumes/foo_disk'
        @mounted.should == true # "umount" doesn't work when device not mounted (see #6632)
        @mounted = false
        ''
      else
        fail "Unexpected command #{command.inspect} executed"
      end
    end
  end

  after :each do
    Puppet::Type::Mount::ProviderParsed.clear # Work around bug #6628
  end

  def check_fstab(expected_to_be_present)
    # Verify that the fake fstab has the expected data in it
    expected_data = expected_to_be_present ? ["/dev/disk1s1\t/Volumes/foo_disk\tmsdos\t#{@desired_options}\t0\t0"] : []
    File.read(@fake_fstab).lines.map(&:chomp).reject { |x| x =~ /^#|^$/ }.should == expected_data
  end

  def run_in_catalog(settings)
    resource = Puppet::Type.type(:mount).new(settings.merge(:name => "/Volumes/foo_disk",
                                             :device => "/dev/disk1s1", :fstype => "msdos"))
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to the filebucket
    resource.expects(:err).never
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false # Stop Puppet from doing a bunch of magic
    catalog.add_resource resource
    catalog.apply
  end

  [false, true].each do |initial_state|
    describe "When initially #{initial_state ? 'mounted' : 'unmounted'}" do
      before :each do
        @mounted = initial_state
      end

      [false, true].each do |initial_fstab_entry|
        describe "When there is #{initial_fstab_entry ? 'an' : 'no'} initial fstab entry" do
          before :each do
            create_fake_fstab(initial_fstab_entry)
          end

          [:defined, :present, :mounted, :unmounted, :absent].each do |ensure_setting|
            expected_final_state = case ensure_setting
              when :mounted
                true
              when :unmounted, :absent
                false
              when :defined, :present
                initial_state
              else
                fail "Unknown ensure_setting #{ensure_setting}"
            end
            expected_fstab_data = (ensure_setting != :absent)
            describe "When setting ensure => #{ensure_setting}" do
              ["local", "journaled"].each do |options_setting|
                describe "When setting options => #{options_setting}" do
                  it "should leave the system in the #{expected_final_state ? 'mounted' : 'unmounted'} state, #{expected_fstab_data ? 'with' : 'without'} data in /etc/fstab" do
                    @desired_options = options_setting
                    run_in_catalog(:ensure=>ensure_setting, :options => options_setting)
                    @mounted.should == expected_final_state
                    check_fstab(expected_fstab_data)
                    if @mounted
                      if ![:defined, :present].include?(ensure_setting)
                        @current_options.should == @desired_options
                      elsif initial_fstab_entry
                        @current_options.should == @desired_options
                      else
                        @current_options.should == 'local' #Workaround for #6645
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
