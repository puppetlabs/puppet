test_name "puppet module list (with missing dependencies)"

tag 'audit:low',
    'audit:unit'

teardown do
  on master, "rm -rf #{master['distmoduledir']}/thelock"
  on master, "rm -rf #{master['distmoduledir']}/appleseed"
  on master, "rm -rf #{master['sitemoduledir']}/crick"
end

step "Setup"

apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/appleseed',
    '#{master['distmoduledir']}/thelock',
    '#{master['sitemoduledir']}/crick',
  ]: ensure => directory,
     recurse => true,
     purge => true,
     force => true;
  '#{master['distmoduledir']}/appleseed/metadata.json':
    content => '{
      "name": "jimmy/appleseed",
      "version": "1.1.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": "0.4.0" }
      ]
    }';
  '#{master['distmoduledir']}/thelock/metadata.json':
    content => '{
      "name": "jimmy/thelock",
      "version": "1.0.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/appleseed", "version_requirement": "1.x" },
        { "name": "jimmy/sprinkles", "version_requirement": "2.x" }
      ]
    }';
  '#{master['sitemoduledir']}/crick/metadata.json':
    content => '{
      "name": "jimmy/crick",
      "version": "1.0.1",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": [
        { "name": "jimmy/crakorn", "version_requirement": "0.4.x" }
      ]
    }';
}
PP

on master, "[ -d #{master['distmoduledir']}/appleseed ]"
on master, "[ -d #{master['distmoduledir']}/thelock ]"
on master, "[ -d #{master['sitemoduledir']}/crick ]"

step "List the installed modules"
on master, puppet('module list') do
  pattern = Regexp.new([
    %Q{.*Warning: Missing dependency 'jimmy-crakorn':},
    %Q{  'jimmy-appleseed' \\(v1.1.0\\) requires 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{  'jimmy-crick' \\(v1.0.1\\) requires 'jimmy-crakorn' \\(v0.4.x\\).*},
    %Q{.*Warning: Missing dependency 'jimmy-sprinkles':},
    %Q{  'jimmy-thelock' \\(v1.0.0\\) requires 'jimmy-sprinkles' \\(v2.x\\).*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)
end

step "List the installed modules as a dependency tree"
on master, puppet('module list --tree') do
  pattern = Regexp.new([
    %Q{.*Warning: Missing dependency 'jimmy-crakorn':},
    %Q{  'jimmy-appleseed' \\(v1.1.0\\) requires 'jimmy-crakorn' \\(v0.4.0\\)},
    %Q{  'jimmy-crick' \\(v1.0.1\\) requires 'jimmy-crakorn' \\(v0.4.x\\).*},
    %Q{.*Warning: Missing dependency 'jimmy-sprinkles':},
    %Q{  'jimmy-thelock' \\(v1.0.0\\) requires 'jimmy-sprinkles' \\(v2.x\\).*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)

  assert_match /UNMET DEPENDENCY.*jimmy-sprinkles/, stdout, 'Did not find unmeet dependency for jimmy-sprinkles warning'

  assert_match /UNMET DEPENDENCY.*jimmy-crakorn/, stdout, 'Did not find unmeet dependency for jimmy-crakorn warning'
end
