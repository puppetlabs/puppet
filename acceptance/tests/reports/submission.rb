test_name "Report submission"

testdir = master.tmpdir('report_submission')

with_master_running_on(master, "--reportdir #{testdir} --reports store --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
  agents.each do |agent|
    run_agent_on(agent, "-t --server #{master}")

    on master, "grep -q #{agent} #{testdir}/*/*"
  end
end

on master, "rm -rf #{testdir}"
