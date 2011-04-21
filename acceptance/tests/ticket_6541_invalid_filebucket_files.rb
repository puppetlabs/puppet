test_name "start with a file"
manifest = "file { '/tmp/6541': content => 'some text' }"
apply_manifest_on(agents, manifest)

test_name "verify invalid hashes should not change the file"
manifest = "file { '/tmp/6541': content => '{md5}notahash' }"
apply_manifest_on(agents, manifest) do
  fail_test "shouldn't have overwrote the file" if
    stdout =~ /content changed/
end

test_name "verify valid but unbucketed hashes should not change the file"
manifest = "file { '/tmp/6541': content => '{md5}13ad7345d56b566a4408ffdcd877bc78' }"
apply_manifest_on(agents, manifest) do
  fail_test "shouldn't have overwrote the file" if
    stdout =~ /content changed/
end

on(agents, puppet_filebucket("backup -l /dev/null") )

test_name "verify that an empty file can be retrieved from the filebucket"
manifest = "file { '/tmp/6541': content => '{md5}d41d8cd98f00b204e9800998ecf8427e' }"
apply_manifest_on(agents, manifest) do
  fail_test "shouldn't have overwrote the file" unless
    stdout =~ /content changed '\{md5\}552e21cd4cd9918678e3c1a0df491bc3' to '\{md5\}d41d8cd98f00b204e9800998ecf8427e'/
end
