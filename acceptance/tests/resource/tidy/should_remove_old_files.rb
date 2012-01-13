test_name "Tidying files by date"

step "Create a directory of old and new files"

dir = "/tmp/tidy-test-#{$$}"
on agents, "mkdir -p #{dir}"
# YYMMddhhmm, so 03:04 Jan 2 1970
old = %w[one two three four five]
new = %w[a b c d e]
on agents, "touch -t 7001020304 #{dir}/{#{old.join(',')}}"
on agents, "touch #{dir}/{#{new.join(',')}}"

step "Run a tidy resource to remove the old files"

manifest = <<-MANIFEST
  tidy { "#{dir}":
    age     => '1d',
    recurse => true,
  }
MANIFEST

apply_manifest_on agents, manifest

step "Ensure the old files are gone"

old_test = old.map {|name| "-f #{File.join(dir, name)}"}.join(' -o ')

on agents, "[ #{old_test} ]", :acceptable_exit_codes => [1]

step "Ensure the new files are still present"

new_test = new.map {|name| "-f #{File.join(dir, name)}"}.join(' -a ')

on agents, "[ #{new_test} ]"
