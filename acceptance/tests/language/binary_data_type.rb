test_name 'C98346: Binary data type' do
  require 'puppet/acceptance/puppet_type_test_tools.rb'
  extend Puppet::Acceptance::PuppetTypeTestTools

  tag 'audit:high',
      'audit:integration' # Tests that binary data is retains integrity
      # between server and agent transport/application.
      # The weak link here is final ruby translation and
      # should not be OS sensitive.

  app_type               = File.basename(__FILE__, '.*')
  tmp_environment        = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath = "#{environmentpath}/#{tmp_environment}"

  tmp_filename_win = tmp_filename_else = ''
  agents.each do |agent|
    # ugh... this won't work with more than two agents of two types
    if agent.platform =~ /32$/
      tmp_filename_win = "C:\\cygwin\\tmp\\#{tmp_environment}.txt"
    else
      tmp_filename_win = "C:\\cygwin64\\tmp\\#{tmp_environment}.txt"
    end
    tmp_filename_else = "/tmp/#{tmp_environment}.txt"
    if agent.platform =~ /windows/
      tmp_filename = tmp_filename_win
    else
      tmp_filename = tmp_filename_else
    end
    on(agent, "echo 'old content' > '/tmp/#{tmp_environment}.txt'")
  end
  # create a fake module files... file for binary_file()
  on(master, puppet_apply("-e 'file{[\"#{environmentpath}/#{tmp_environment}/modules\",\"#{environmentpath}/#{tmp_environment}/modules/empty\",\"#{environmentpath}/#{tmp_environment}/modules/empty/files\"]: ensure => \"directory\"} file{\"#{environmentpath}/#{tmp_environment}/modules/empty/files/blah.txt\": content => \"binary, yo\"}'"))

  base64_relaxed = Base64.encode64("invasionfromspace#{random_string}").strip
  base64_strict  = Base64.strict_encode64("invasion from space #{random_string}\n")
  base64_urlsafe = Base64.urlsafe_encode64("invasion from-space/#{random_string}\n")

  test_resources = [
      { :type       => 'notify', :parameters => { :namevar => "1:$hell" }, :pre_code => "$hell = Binary('hello','%b')",
        :assertions => { :assert_match => 'Notice: 1:hell' } },
      { :type       => 'notify', :parameters => { :namevar => "2:$relaxed" }, :pre_code => "$relaxed = Binary('#{base64_relaxed}')",
        :assertions => { :assert_match => "Notice: 2:#{base64_relaxed}" } },
      { :type       => 'notify', :parameters => { :namevar => "3:$cHVwcGV0" }, :pre_code => "$cHVwcGV0 = Binary('cHVwcGV0')",
        :assertions => { :assert_match => 'Notice: 3:cHVwcGV0' } },
      { :type       => 'notify', :parameters => { :namevar => "4:$strict" }, :pre_code => "$strict = Binary('#{base64_strict}')",
        :assertions => { :assert_match => "Notice: 4:#{base64_strict}" } },
      { :type       => 'notify', :parameters => { :namevar => "5:$urlsafe" }, :pre_code => "$urlsafe = Binary('#{base64_urlsafe}')",
        :assertions => { :assert_match => "Notice: 5:#{base64_urlsafe}" } },
      { :type       => 'notify', :parameters => { :namevar => "6:$byte_array" }, :pre_code => "$byte_array = Binary([67,68])",
        :assertions => { :assert_match => "Notice: 6:Q0Q=" } },
      { :type       => 'notify', :parameters => { :namevar => "7:${empty_array}empty" }, :pre_code => "$empty_array = Binary([])",
        :assertions => { :assert_match => "Notice: 7:empty" } },
      { :type       => 'notify', :parameters => { :namevar => "8:${relaxed[1]}" },
        :assertions => { :assert_match => "Notice: 8:bg==" } },
      { :type       => 'notify', :parameters => { :namevar => "9:${relaxed[1,3]}" },
        :assertions => { :assert_match => "Notice: 9:bnZh" } },
      { :type       => 'notify', :parameters => { :namevar => "A:${utf8}" }, :pre_code => '$utf8=String(Binary([0xF0, 0x9F, 0x91, 0x92]),"%s")',
        :assertions => { :assert_match => 'Notice: A:\\xF0\\x9F\\x91\\x92' } },
      { :type       => 'notify', :parameters => { :namevar => "B:${type($bin_file)}" }, :pre_code => '$bin_file=binary_file("empty/blah.txt")',
        :assertions => { :assert_match => 'Notice: B:Binary' } },
      { :type       => 'file', :parameters => { :namevar => "$pup_tmp_filename", :content => "$relaxed" }, :pre_code => "$pup_tmp_filename = if $osfamily == 'windows' { '#{tmp_filename_win}' } else { '#{tmp_filename_else}' }",
        :assertions => { :assert_match => /#{base64_relaxed}/ } },
  ]

  sitepp_content = generate_manifest(test_resources)
  assertion_code = generate_assertions(test_resources)

  create_sitepp(master, tmp_environment, sitepp_content)

  step "run agent in #{tmp_environment}, run all assertions" do
    with_puppet_running_on(master, {}) do
      agents.each do |agent|
        on(agent, puppet("agent -t --server #{master.hostname} --environment '#{tmp_environment}'"), :acceptable_exit_codes => [2]) do |result|
          run_assertions(assertion_code, result)
        end
      end
    end
  end

end
