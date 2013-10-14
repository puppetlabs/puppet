test_name "Report submission"

if master.is_pe?
  require "time"

  def query_last_report_time_on(agent)
    time_query_script = <<-EOS
      require "net/http"
      require "json"

      puppetdb_url = URI("http://localhost:8080/v3/reports")
      puppetdb_url.query = URI.escape(%Q{query=["=","certname","#{agent}"]})
      result = Net::HTTP.get(puppetdb_url)
      json = JSON.load(result)
      puts json.first["receive-time"]
    EOS
    puppetdb = hosts.detect { |h| h['roles'].include?('database') }
    on(puppetdb, "#{master[:puppetbindir]}/ruby -e '#{time_query_script}'").output.chomp
  end

  last_times = {}

  agents.each do |agent|
    last_times[agent] = query_last_report_time_on(agent)
  end

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on(agent, puppet('agent', "-t --server #{master}"))

      current_time = Time.parse(query_last_report_time_on(agent))
      last_time = Time.parse(last_times[agent])

      assert(current_time > last_time, "Most recent report time #{current_time} is not newer than last report time #{last_time}")
    end
  end

else

  testdir = master.tmpdir('report_submission')

  teardown do
    on master, "rm -rf #{testdir}"
  end

  with_puppet_running_on(master, :main => { :reportdir => testdir, :reports => 'store' }) do
    agents.each do |agent|
      on(agent, puppet('agent', "-t --server #{master}"))

      on master, "grep -q #{agent} #{testdir}/*/*"
    end
  end

end
