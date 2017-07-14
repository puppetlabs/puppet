test_name 'PUP-3981 - C63215 - Build Module Should Ignore Module File'

tag 'audit:low',
    'audit:acceptance'
    'audit:refactor'   # Wrap steps in blocks in accordance with Beaker style guide

#Init
temp_module_path = master.tmpdir('build_ignore_module_file_test')
metadata_json_file_path = File.join(temp_module_path, 'metadata.json')
modulefile_file_path = File.join(temp_module_path, 'Modulefile')

#In-line File
metadata_json_file = <<-FILE
{
  "name": "puppetlabs-test",
  "version": "0.0.1",
  "author": "Puppet Labs",
  "summary": "Test Module",
  "license": "Apache Version 2.0",
  "source": "git://github.com/puppetlabs/puppetlabs-test.git",
  "project_page": "https://github.com/puppetlabs/puppetlabs-test",
  "issues_url": "https://github.com/puppetlabs/puppetlabs-test",
  "dependencies": [
    {"name":"puppetlabs-stdlub","version_requirement":">= 1.0.0"}
  ]
}
FILE

#Verification
modulefile_ignore_message_regex = /Warning: A Modulefile was found in the root directory of the module. This file will be ignored and can safely be removed./

#Teardown
teardown do
  step 'Teardown Test Artifacts'
  on(master, "rm -rf #{temp_module_path}")
end

#Setup
step 'Create "metadata.json" for Temporary Module'
create_remote_file(master, metadata_json_file_path, metadata_json_file)

step 'Create "Modulefile" for Temporary Module'
create_remote_file(master, modulefile_file_path, 'Empty')

#Tests
step 'Build Module with Modulefile Present'
on(master, puppet("module build #{temp_module_path}")) do |result|
  assert_no_match(/Error:/, result.output, 'Unexpected error was detected!')
  assert_match(modulefile_ignore_message_regex, result.output, 'Expected message not found!')
end
