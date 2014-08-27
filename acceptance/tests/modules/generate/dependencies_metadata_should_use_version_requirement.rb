test_name "puppet module generate - dependencies in metadata.json should use 'version_requirement' NOT 'version_range'"
require 'json'

module_author = "foo"
module_name   = "bar"
module_dependencies = []

agents.each do |agent|

  teardown do
    on agent,"rm -fr #{module_author}-#{module_name}"
  end

  step "Generate #{module_author}-#{module_name} module" do
    on agent, puppet("module generate #{module_author}-#{module_name} --skip-interview")
  end

  step "Check for 'version_requirement' in metadata.json" do
    on agent,"test -f #{module_author}-#{module_name}/metadata.json"

    on agent,"cat #{module_author}-#{module_name}/metadata.json" do |res|
      metadata = res.stdout.chomp
      m = JSON.parse(metadata)
      fail_test('version_requirement not in dependencies keys') unless m['dependencies'][0].keys.include? 'version_requirement'
      fail_test('version_range in dependencies keys') if m['dependencies'][0].keys.include? 'version_range'
    end
  end

end
