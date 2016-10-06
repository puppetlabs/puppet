test_name 'C98120, C98077: Sensitive Data is redacted on CLI, logs, reports' do
require 'puppet/acceptance/puppet_type_test_tools.rb'
extend Puppet::Acceptance::PuppetTypeTestTools

  app_type        = File.basename(__FILE__, '.*')
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  fq_tmp_environmentpath  = "#{environmentpath}/#{tmp_environment}"

  tmp_filename_win = tmp_filename_else = ''
  agents.each do |agent|
    # ugh... this won't work with more than two agents of two types
    if agent.platform =~ /32$/
      tmp_filename_win  = "C:\\cygwin\\tmp\\#{tmp_environment}.txt"
    else
      tmp_filename_win  = "C:\\cygwin64\\tmp\\#{tmp_environment}.txt"
    end
    tmp_filename_else = "/tmp/#{tmp_environment}.txt"
    if agent.platform =~ /windows/
      tmp_filename = tmp_filename_win
    else
      tmp_filename = tmp_filename_else
    end
    on agent, "echo 'old content' > /tmp/#{tmp_environment}.txt"
  end

  # first attempts at a reasonable table driven test.  needs API work
  # FIXME:
  #   expand this to other resource types, make parameters arbitrary, make assertions arbitrary
  # FIXME: add context messaging to each instance
  notify_redacted = 'Sensitive \[value redacted\]'
  file_redacted   = 'changed \[redacted\] to \[redacted\]'
  test_resources = [
    {:type => 'notify', :parameters => {:namevar => "1:${Sensitive.new('sekrit1')}"},
       :assertions => [{:refute_match => 'sekrit1'}, {:assert_match => "1:#{notify_redacted}"}]},
    {:type => 'notify', :parameters => {:namevar => "2:${Sensitive.new($meh2)}"}, :pre_code => '$meh2="sekrit2"',
       :assertions => [{:refute_match => 'sekrit2'}, {:assert_match => "2:#{notify_redacted}"}]},
    {:type => 'notify', :parameters => {:namevar => "3:meh", :message => '"3:${Sensitive.new(\'sekrit3\')}"'},
       :assertions => [{:refute_match => 'sekrit3'}, {:assert_match => "3:#{notify_redacted}"}]},
    {:type => 'notify', :parameters => {:namevar => "4:meh", :message => "Sensitive.new($meh4)"}, :pre_code => '$meh4="sekrit4"',
       :assertions => {:expect_failure => {:refute_match => 'sekrit4', :message => 'you can always spill redacted data, if you want to'}}},
    {:type => 'notify', :parameters => {:namevar => "5:meh", :message => "$meh5"}, :pre_code => '$meh5=Sensitive.new("sekrit5")',
       :assertions => {:expect_failure => {:refute_match => 'sekrit5', :message => 'you can always spill redacted data, if you want to'}}},
    {:type => 'notify', :parameters => {:namevar => "6:meh", :message => '"6:${meh6}"'}, :pre_code => '$meh6=Sensitive.new("sekrit6")',
       :assertions => [{:refute_match => 'sekrit6'}, {:assert_match => "6:#{notify_redacted}"}]},
    {:type => 'notify', :parameters => {:namevar => "7:${Sensitive('sekrit7')}"},
       :assertions => [{:refute_match => 'sekrit7'}, {:assert_match => "7:#{notify_redacted}"}]},
    # unwrap(), these should be en-clair
    {:type => 'notify', :parameters => {:namevar => "8:${unwrap(Sensitive.new('sekrit8'))}"},
       :assertions => {:assert_match => "8:sekrit8"}},
    {:type => 'notify', :parameters => {:namevar => "9:meh", :message => '"9:${unwrap(Sensitive.new(\'sekrit9\'))}"'},
       :assertions => {:assert_match => "9:sekrit9"}},
    {:type => 'notify', :parameters => {:namevar => "A:meh", :message => '"A:${unwrap($mehA)}"'}, :pre_code => '$mehA=Sensitive.new("sekritA")',
       :assertions => {:assert_match => "A:sekritA"}},
    {:type => 'notify', :parameters => {:namevar => "B:meh", :message => '"B:${$mehB.unwrap}"'}, :pre_code => '$mehB=Sensitive.new("sekritB")',
       :assertions => {:assert_match => "B:sekritB"}},
    {:type => 'notify', :parameters => {:namevar => "C:meh", :message => '"C:${$mehC.unwrap |$unwrapped| { "blk_${unwrapped}_blk" } } nonblk_${mehC}_nonblk"'}, :pre_code => '$mehC=Sensitive.new("sekritC")',
       :assertions => {:assert_match => ["C:blk_sekritC_blk", "nonblk_#{notify_redacted}_nonblk"]}},
    # for --show_diff
    {:type => 'file', :parameters => {:namevar => "$pup_tmp_filename", :content => "Sensitive.new('sekritD')"}, :pre_code => "$pup_tmp_filename = if $osfamily == 'windows' { '#{tmp_filename_win}' } else { '#{tmp_filename_else}' }",
       :assertions => [{:refute_match => 'sekritD'}, {:assert_match => /#{tmp_environment}\.txt..content. #{file_redacted}/}]},

  ]

  sitepp_content = generate_manifest(test_resources)
  assertion_code = generate_assertions(test_resources)

  create_sitepp(master, tmp_environment, sitepp_content)

  step "run agent in #{tmp_environment}, run all assertions" do
    with_puppet_running_on(master,{}) do
      agents.each do |agent|
        on(agent, puppet("agent -t --debug --trace --show_diff --server #{master.hostname} --environment #{tmp_environment}"),
           :accept_all_exit_codes => true) do |result|
          assert(result.exit_code==2,'puppet agent run failed')
          run_assertions(assertion_code, result)
        end

        if agent['platform'] =~ /fedora|centos|el|redhat|scientific|ubuntu|debian|cumulus/
          step "assert no redacted data in syslog" do
            #sigh.  gee, thanks for the help, beaker!
            result = dump_puppet_log(agent)
            raise if result.length < 3
            string_io_index = 2
            run_assertions(assertion_code, result[string_io_index].string)
          end
        end

        # don't do this before the agent log scanning, above. it will skew the results
        step "assert no redacted data in vardir" do
          # no recursive grep in solaris :facepalm:
          on(agent, "find #{agent.puppet['vardir']} -type f | xargs grep sekrit", :accept_all_exit_codes => true) do |result|
            refute_match(/sekrit(1|2|3|6|7)/, result.stdout, 'found redacted data we should not have')
            #TODO: if/when this is fixed, we should just be able to eval(assertion_code_ in this result block also!
            expect_failure 'file resource contents will end up in the cached catalog en-clair' do
              refute_match(/sekritD/, result.stdout, 'found redacted file data we should not have')
            end
          end
        end

      end
    end
  end

end
