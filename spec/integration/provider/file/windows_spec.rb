require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'

# For some reason the provider test will not filter out on windows when using the
# :if => Puppet.features.microsoft_windows? method of filtering the tests.
if Puppet.features.microsoft_windows?
  require 'puppet/util/windows'
  describe Puppet::Type.type(:file).provider(:windows), '(integration)' do
    include PuppetSpec::Compiler
    include PuppetSpec::Files

    def create_temp_file(owner_sid, group_sid, initial_mode)
      tmp_file = tmpfile('filewindowsprovider')
      File.delete(tmp_file) if File.exist?(tmp_file)
      File.open(tmp_file, 'w') { |file| file.write("rspec test") }

      # There are other tests to ensure that these methods do indeed
      # set the owner and group.  Therefore it's ok to depend on them
      # here
      Puppet::Util::Windows::Security.set_owner(owner_sid, tmp_file) unless owner_sid.nil?
      Puppet::Util::Windows::Security.set_group(group_sid, tmp_file) unless group_sid.nil?
      # Pretend we are managing the owner and group to FORCE this mode, even if it's "bad"
      Puppet::Util::Windows::Security.set_mode(initial_mode.to_i(8), tmp_file, true, true, true) unless initial_mode.nil?

      tmp_file
    end

    def strip_sticky(value)
      # For the purposes of these tests we don't care about the extra-ace bit in modes
      # This function removes it
      value & ~Puppet::Util::Windows::Security::S_IEXTRA
    end

    sids = {
      :system => Puppet::Util::Windows::SID::LocalSystem,
      :administrators => Puppet::Util::Windows::SID::BuiltinAdministrators,
      :users => Puppet::Util::Windows::SID::BuiltinUsers,
      :power_users => Puppet::Util::Windows::SID::PowerUsers,
      :none => Puppet::Util::Windows::SID::Nobody,
      :everyone => Puppet::Util::Windows::SID::Everyone
    }

    # Testcase Hash options
    # create_* : These options are used when creating the initial test file
    # create_owner (Required!)
    # create_group (Required!)
    # create_mode
    #
    # manifest_* : These options are used to craft the manifest which is applied to the test file after createion
    # manifest_owner,
    # manifest_group,
    # manifest_mode (Required!)
    #
    # actual_* : These options are used to check the _actual_ values as opposed to the munged values from puppet
    # actual_mode (Uses manifest_mode for checks if not set)

    RSpec.shared_examples "a mungable file resource" do |testcase|

      before(:each) do
        @tmp_file = create_temp_file(sids[testcase[:create_owner]], sids[testcase[:create_group]], testcase[:create_mode])
        raise "Could not create temporary file" if @tmp_file.nil?
      end

      after(:each) do
        File.delete(@tmp_file) if File.exist?(@tmp_file)
      end

      context_name = "With initial owner '#{testcase[:create_owner]}' and initial group '#{testcase[:create_owner]}'"
      context_name += " and initial mode of '#{testcase[:create_mode]}'" unless testcase[:create_mode].nil?
      context_name += " and a mode of '#{testcase[:manifest_mode]}' in the manifest"
      context_name += " and an owner of '#{testcase[:manifest_owner]}' in the manifest" unless testcase[:manifest_owner].nil?
      context_name += " and a group of '#{testcase[:manifest_group]}' in the manifest" unless testcase[:manifest_group].nil?

      context context_name do
        is_idempotent = testcase[:is_idempotent].nil? || testcase[:is_idempotent]

        let(:manifest) do
          value = <<-MANIFEST
            file { 'rspec_example':
              ensure => present,
              path   => '#{@tmp_file}',
              mode   => '#{testcase[:manifest_mode]}',
          MANIFEST
          value += "  owner  => '#{testcase[:manifest_owner]}',\n" unless testcase[:manifest_owner].nil?
          value += "  group  => '#{testcase[:manifest_group]}',\n" unless testcase[:manifest_group].nil?
          value + "}"
        end

        it "should apply with no errors and have expected ACL" do
          apply_with_error_check(manifest)
          new_mode = strip_sticky(Puppet::Util::Windows::Security.get_mode(@tmp_file))
          expect(new_mode.to_s(8)).to eq (testcase[:actual_mode].nil? ? testcase[:manifest_mode] : testcase[:actual_mode])
        end

        it "should be idempotent", :if => is_idempotent do
          result = apply_with_error_check(manifest)
          result = apply_with_error_check(manifest)
          # Idempotent. Should be no changed resources
          expect(result.changed?.count).to eq 0
        end

        it "should NOT be idempotent", :unless => is_idempotent do
          result = apply_with_error_check(manifest)
          result = apply_with_error_check(manifest)
          result = apply_with_error_check(manifest)
          result = apply_with_error_check(manifest)
          # Not idempotent. Expect changed resources
          expect(result.changed?.count).to be > 0
        end
      end
    end

    # These scenarios round-trip permissions and are idempotent
    [
      { :create_owner => :system,         :create_group => :administrators, :manifest_mode => '760' },
      { :create_owner => :administrators, :create_group => :administrators, :manifest_mode => '660' },
      { :create_owner => :system,         :create_group => :system,         :manifest_mode => '770' },
    ].each do |testcase|
      # What happens if the owner and group are not managed
      it_behaves_like "a mungable file resource", testcase
      # What happens if the owner is managed
      it_behaves_like "a mungable file resource", testcase.merge({ :manifest_owner => testcase[:create_owner]})
      # What happens if the group is managed
      it_behaves_like "a mungable file resource", testcase.merge({ :manifest_group => testcase[:create_group]})
      # What happens if both the owner and group are managed
      it_behaves_like "a mungable file resource", testcase.merge({
        :manifest_owner => testcase[:create_owner],
        :manifest_group => testcase[:create_group]
      })
    end

    # SYSTEM is special in that when specifying less than mode 7, the owner and/or group MUST be managed
    # otherwise it's munged to 7 behind the scenes and is not idempotent
    both_system_testcase = { :create_owner => :system, :create_group => :system, :manifest_mode => '660', :actual_mode => '770', :is_idempotent => false }
    # What happens if the owner and group are not managed
    it_behaves_like "a mungable file resource", both_system_testcase.merge({ :is_idempotent => true })
    # What happens if the owner is managed
    it_behaves_like "a mungable file resource", both_system_testcase.merge({ :manifest_owner => both_system_testcase[:create_owner]})
    # What happens if the group is managed
    it_behaves_like "a mungable file resource", both_system_testcase.merge({ :manifest_group => both_system_testcase[:create_group]})

    # However when we manage SYSTEM explicitly, then the modes lower than 7 stick and the file provider
    # assumes it's insync (i.e. idempotent)
    it_behaves_like "a mungable file resource", both_system_testcase.merge({
      :manifest_owner => both_system_testcase[:create_owner],
      :manifest_group => both_system_testcase[:create_group],
      :actual_mode    => both_system_testcase[:manifest_mode],
      :is_idempotent  => true
    })

    # What happens if we _create_ a file that SYSTEM is a part of, and is Full Control, but the manifest says it should not be Full Control
    # Behind the scenes the mode should be changed to 7 and be idempotent
    [
      { :create_owner => :system,         :create_group => :system,         :manifest_mode => '660' },
      { :create_owner => :administrators, :create_group => :system,         :manifest_mode => '760' },
      { :create_owner => :system,         :create_group => :administrators, :manifest_mode => '670' },
    ].each do |testcase|
      it_behaves_like "a mungable file resource", testcase.merge({ :create_mode => '770', :actual_mode => '770'})
    end
  end
end
