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
      @tmpfile = File.join(agent.system_temp_path,tmp_environment,'binfile')
      base64_relaxed = Base64.encode64("invasionfromspace#{random_string}").strip
      on(agent, "echo #{base64_relaxed} > #{@tmpfile}")
    end
  end

  step "create manifest" do
    base64_relaxed2 = Base64.encode64("MOARinvasionfromspace#{random_string}").strip
    create_sitepp(master, tmp_environment, "File{'#{@tmpfile}': content => Binary('#{base64_relaxed2}')}")
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
