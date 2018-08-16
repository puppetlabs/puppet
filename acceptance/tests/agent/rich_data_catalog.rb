test_name "rich_data on master and agent" do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tag "audit:high",
    "audit:acceptance",
    "server"

  def create_environmentconf(host, environment, contents)
    fq_tmp_environmentpath = "#{environmentpath}/#{environment}"
    create_remote_file(host, "#{fq_tmp_environmentpath}/environment.conf", contents)
    on(host, "chown -R #{host.puppet['user']}:#{host.puppet['group']} " +
             "#{fq_tmp_environmentpath}/environment.conf")
    on(host, "chmod -R 755 #{fq_tmp_environmentpath}/environment.conf")
  end

  app_type        = File.basename(__FILE__, ".*")
  tmp_environment = mk_tmp_environment_with_teardown(master, app_type)
  tmp_filename_win = tmp_filename_else = ''
  agents.each do |agent|
    # FIXME: ugh... this won't work with more than two agents of two types
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
  end

  step "turn on rich_data in agents environment" do
    create_environmentconf(master, tmp_environment, "rich_data = true")
  end

  step "turn on rich_data on agents" do
    on(agents, puppet("config set rich_data true --section agent"))
    teardown do
      on(agents, puppet("config delete rich_data --section agent"))
    end
  end

  @json_catalog = Array.new
  agents.each_with_index do |agent,i|
    step "delete any old catalogs" do
      @json_catalog[i] = File.join(agent.puppet['client_datadir'], 'catalog',
                                   "#{agent.puppet['certname']}.json")
      on(agent, "rm #{@json_catalog[i]}", acceptable_exit_codes: [0,1])
    end
    step "create a binary tmpfile" do
      base64_relaxed = Base64.encode64("invasionfromspace#{random_string}").strip
      # FIXME: ugh... this is terrible.  make this a Host abstraction that works
      if agent['platform'] =~ /windows/
        on(agent, "echo #{base64_relaxed} > #{tmp_filename_win}")
      else
        on(agent, "echo #{base64_relaxed} > #{tmp_filename_else}")
      end
    end
  end

  step "create manifest" do
    base64_relaxed2 = Base64.encode64("MOARinvasionfromspace#{random_string}").strip
    pre_pup_code = "$pup_tmp_filename = if $osfamily == 'windows' { '#{tmp_filename_win}' } else { '#{tmp_filename_else}' }"
    create_sitepp(master, tmp_environment, "#{pre_pup_code}; File{'$pup_tmp_filename': content => Binary('#{base64_relaxed2}')}")
  end

  agents.each_with_index do |agent,i|
    step "run agent" do
      result = on(agent, puppet("agent -t " +
                                "--server #{master.hostname} " +
                                "--environment #{tmp_environment}"),
                  acceptable_exit_codes: [1])
      # when this test starts failing due to upstream fixes, update exit codes to 0,2
      #acceptable_exit_codes: [0,2])

      step "the catalog should have rich data in it" do
        # The catalog file should be parseable JSON
        result = on(agent, "cat #{@json_catalog[i]}",
           acceptable_exit_codes: [1])
        # when this test starts failing due to upstream fixes, update exit codes to 0 (remove)
        expect_failure("catalog isn't there, but it should contain __pvalue") do
          assert_match(/__pvalue/,result.stdout.chomp,"catalog should have rich types and values")
        end
      end
    end
  end
end
