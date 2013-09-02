test_name "Report submission"

testdir = master.tmpdir('report_submission')

with_puppet_running_on(master, :main => { :reportdir => testdir, :reports => 'store', :daemonize => true, :autosign => true }) do
  agents.each do |agent|
    run_agent_on(agent, "-t --server #{master}")

    on master, "grep -q #{agent} #{testdir}/*/*"
  end
end

on master, "rm -rf #{testdir}"
