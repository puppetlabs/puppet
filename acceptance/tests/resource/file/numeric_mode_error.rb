test_name 'puppet errors if file resource specified with numeric mode'
# TestRail test case C14937

agents.each do |a|

  testdir = a.tmpdir('no-numeric-modes')
  testfile = File.join(testdir, 'jenny')

  teardown do
    on(a, 'rm -fvr #{testdir}', :accept_all_exit_codes => true)
  end

  step 'Cannot create a new file with a numeric mode attrbute' do
    manifest = <<-MANIFEST
      file { "#{testfile}": ensure => present, mode => 0666 }
    MANIFEST

    apply_manifest_on(a, manifest, :acceptable_exit_codes => [1])    
    fail_test "Puppet accepted numeric file mode attributes on a new file" unless stderr.include? "The file mode specification must be a string"
  end
  
  step 'Cannot change the mode of an existing file using a numeric mode attribute' do
    manifest = <<-MANIFEST
      file { "#{testdir}": ensure => directory, mode => '0755' }
      file { "#{testfile}": ensure => present, mode => '0666' }
    MANIFEST

    # Make the target file
    apply_manifest_on(a, manifest, :acceptable_exit_codes => [0])
    # Try to change its mode 
    apply_manifest_on(a, "file { '#{testfile}': mode => 0777 }", :acceptable_exit_codes => [1])
    fail_test "Puppet accepted numeric file mode attributes on an existing file" unless stderr.include? "The file mode specification must be a string"
  end
end
