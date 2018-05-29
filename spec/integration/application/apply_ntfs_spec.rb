# require 'spec_helper'

# require 'puppet/application/apply'

# # [:main, :reporting, :metrics]


# def with_acl_hash(path, &block)
#   # Note - This does not work with paths with a single quote in them
#   # Note - ConvertTo-JSON requires PS3 or above
#   ps_script = <<-EOT
# $Path = '#{path}';
# (Get-ACL $Path).access | ForEach-Object {
# New-Object -TypeName PSObject -Property @{
#   'FileSystemRights' = $_.FileSystemRights.ToString();
#   'AccessControlType' = $_.AccessControlType.ToString();
#   'IdentityReference' = $_.IdentityReference.Value.ToString();
#   'IsInherited' = $_.IsInherited;
#   'InheritanceFlags' = $_.InheritanceFlags.ToString();
#   'PropagationFlags' = $_.PropagationFlags.ToString();
#   'Path' = $Path;
# }
# } | ConvertTo-JSON
# EOT
#   cmd = "powershell -NoLogo -NoProfile -NonInteractive -Command \"#{ps_script.gsub("\n","")}\""

#   result = %x[ #{cmd} ]
# puts "SSSSS #{path}"
#   begin
#     yield JSON.parse(result)
#   rescue JSON::ParserError
#     raise "Failed to get ACL of #{path}. #{result}"
#   end
# end

# # Custom matchers for ACL hashesw
# RSpec::Matchers.define :contain_only_inherited_aces do
#   match do |actual|
#     find_aces(actual).nil?
#   end

#   failure_message do |actual|
#     "expected that #{find_aces(actual)} would contain only inherited ACEs"
#   end

#   def find_aces(acl)
#     acl.find { |ace| ace['IsInherited'] != true }
#   end
# end

# RSpec::Matchers.define :contain_any_inherited_aces do
#   match do |actual|
#     !find_aces(actual).nil?
#   end

#   failure_message do |actual|
#     "expected that #{actual[0]['Path']} would contain at least one inherited ACE"
#   end

#   def find_aces(acl)
#     acl.find { |ace| ace['IsInherited'] == true }
#   end
# end

# RSpec::Matchers.define :contain_identity_reference do |identity_reference|
#   match do |actual|
#     !find_aces(actual, identity_reference).nil?
#   end

#   failure_message do |actual|
#     "expected that #{actual[0]['Path']} would contain at least one ACE for identity #{identity_reference}"
#   end

#   failure_message_when_negated do |actual|
#     "expected that #{find_aces(actual, identity_reference)} would not contain an ACE for identity #{identity_reference}"
#   end

#   def find_aces(acl, identity_reference)
#     acl.find { |ace| ace['IdentityReference'].casecmp(identity_reference) == 0 }
#   end
# end

# def default_directory_settings
#   [:pluginfactdest, :libdir, :localedest, :reportdir]
# end

# def protected_directory_settings
#   [:logdir, :preview_outputdir, :rundir, :statedir]
# end

# def all_directory_settings
#   default_directory_settings + protected_directory_settings
# end

# # describe Puppet::Application::Apply do
# #   before :each do
# #     @apply = Puppet::Application[:apply]

# #     Puppet[:prerun_command] = ''
# #     Puppet[:postrun_command] = ''
# #   end

# #   after :each do
# #     Puppet::Node::Facts.indirection.reset_terminus_class
# #     Puppet::Node::Facts.indirection.cache_class = nil

# #     Puppet::Node.indirection.reset_terminus_class
# #     Puppet::Node.indirection.cache_class = nil
# #   end



# #--------


# describe


# #----------







#   # # NTFS tests for Windows only platforms
#   # describe "NTFS permissions for an administrative user" do
#   #   before(:each) do
#   #     Puppet.features.stubs(:root?).returns true

#   #     Puppet.initialize_settings([])
#   #     @apply.options[:code] = "notify { 'Hello': }"
#   #     #DEBUG uppet.expects(:[]=).with(:code,"notify { 'Hello': }")
#   #     # Trigger puppet settings to be created
#   #     #Puppet.settings.initialize_global_settings
#   #     #Puppet.settings.use(:main, :reporting, :metrics)
#   #   end

#   #   around(:each) do |example|
#   #     Puppet.settings.initialize_global_settings
#   #     #logger.clear_deprecation_warnings
#   #     #Puppet[:disable_warnings] = ['undefined_variables']
#   #     example.run
#   #     #Puppet[:disable_warnings] = []
#   #   end

#   #   it 'should create folder structure with correct inheritance' do
#   #     puts "confdir = #{Puppet.settings[:confdir]}"
#   #     expect(1).to eq(1)
#   #     #expect { @apply.main }.to exit_with 0

#   #     # Default directories
#   #     # default_directory_settings.each do |setting|
#   #     #   with_acl_hash(Puppet.settings[setting]) do |acl|
#   #     #     expect(acl).to contain_only_inherited_aces
#   #     #   end
#   #     # end

#   #     # # Protected directories
#   #     # protected_directory_settings.each do |setting|
#   #     #   with_acl_hash(Puppet.settings[setting]) do |acl|
#   #     #     expect(acl).not_to contain_any_inherited_aces
#   #     #   end
#   #     # end
#   #   end

#   # end

#   # describe "boo" do

#   #   it 'should not add the NT AUTHORITY\\SYSTEM account, but should add BUILTIN\\Administrators' do
#   #     puts "confdir = #{Puppet.settings[:confdir]}"
#   #     expect(1).to eq(1)
#   #     # expect { @apply.main }.to exit_with 0

#   #     # # Protected directories
#   #     # with_acl_hash(Puppet.settings[:logdir]) do |acl|
#   #     #   expect(acl).not_to contain_any_inherited_aces
#   #     # end

#   #     # with_acl_hash(Puppet.settings[:preview_outputdir]) do |acl|
#   #     #   expect(acl).not_to contain_any_inherited_aces
#   #     # end

#   #     # with_acl_hash(Puppet.settings[:rundir]) do |acl|
#   #     #   expect(acl).not_to contain_any_inherited_aces
#   #     # end

#   #     # with_acl_hash(Puppet.settings[:statedir]) do |acl|
#   #     #   expect(acl).not_to contain_identity_reference('NT AUTHORITY\\SYSTEM')
#   #     #   expect(acl).to contain_identity_reference('BUILTIN\\Administrators')
#   #     # end
#   #   end

#   # end
# # end
