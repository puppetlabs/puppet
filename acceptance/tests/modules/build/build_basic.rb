test_name 'CODEMGMT-69 - Build a Module Using "metadata.json" Only'

tag 'audit:medium',
    'audit:acceptance'
    'audit:refactor'   # Wrap steps in blocks in accordance with Beaker style guide


#Init
temp_module_path = '/tmp/nginx'
metadata_json_file_path = File.join(temp_module_path, 'metadata.json')

#In-line File
metadata_json_file = <<-FILE
{
  "name": "puppetlabs-nginx",
  "version": "0.0.1",
  "author": "Puppet Labs",
  "summary": "Nginx Module",
  "license": "Apache Version 2.0",
  "source": "git://github.com/puppetlabs/puppetlabs-nginx.git",
  "project_page": "https://github.com/puppetlabs/puppetlabs-nginx",
  "issues_url": "https://github.com/puppetlabs/puppetlabs-nginx",
  "dependencies": [
    {"name":"puppetlabs-stdlub","version_requirement":">= 1.0.0"}
  ]
}
FILE

#Verification
build_message_1_regex = /Notice: Building #{temp_module_path} for release/
build_message_2_regex = /Module built: #{temp_module_path}\/pkg\/puppetlabs-nginx-0.0.1.tar.gz/

verify_pkg_dir_command = "[ -d #{temp_module_path}/pkg/puppetlabs-nginx-0.0.1 ]"
verify_tarball_command = "[ -f #{temp_module_path}/pkg/puppetlabs-nginx-0.0.1.tar.gz ]"

#Teardown
teardown do
  step 'Teardown Test Artifacts'
  on(master, "rm -rf #{temp_module_path}")
end

#Setup
step 'Create Temporary Path for Module'
on(master, "mkdir #{temp_module_path}")

step 'Create "metadata.json" for Temporary Module'
create_remote_file(master, metadata_json_file_path, metadata_json_file)

#Tests
step 'Build Module with Absolute Path'
on(master, puppet("module build #{temp_module_path}")) do |result|
  assert_no_match(/Error:/, result.output, 'Unexpected error was detected!')
  assert_no_match(/Warning:/, result.output, 'Unexpected warning was detected!')
  assert_match(build_message_1_regex, result.stdout, 'Expected message not found!')
  assert_match(build_message_2_regex, result.stdout, 'Expected message not found!')
end

step 'Verify Build Artifacts'
on(master, verify_pkg_dir_command)
on(master, verify_tarball_command)

step 'Clean-up Artifacts'
on(master, "rm -rf #{temp_module_path}/pkg")

step "Build Module with Relative Path"
on(master, ("cd #{temp_module_path} && puppet module build")) do |result|
  assert_no_match(/Error:/, result.output, 'Unexpected error was detected!')
  assert_no_match(/Warning:/, result.output, 'Unexpected warning was detected!')
  assert_match(build_message_1_regex, result.stdout, 'Expected message not found!')
  assert_match(build_message_2_regex, result.stdout, 'Expected message not found!')
end

step 'Verify Build Artifacts'
on(master, verify_pkg_dir_command)
on(master, verify_tarball_command)
