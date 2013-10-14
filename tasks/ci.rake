namespace "ci" do
  task :spec do
    ENV["LOG_SPEC_ORDER"] = "true"
    sh %{rspec -r yarjuf -f JUnit -o result.xml -fd spec}
  end

  def get_parameter_value_from_actions(actions, parameter)
    parameters = actions.select { |h| h.key?('parameters') }.first["parameters"]
    parameters.select { |h| h['name'] == parameter }.first['value']
  end

  desc <<-EOS
    Check to see if the job at the url given in DOWNSTREAM_JOB has begun a build including the given BUILD_SELECTOR parameter.
    An example `rake ci:check_for_downstream DOWNSTREAM_JOB='http://jenkins-foss.delivery.puppetlabs.net/job/Puppet-Package-Acceptance-master' BUILD_SELECTOR=123`
    You may optionally set TIMEOUT_MIN, which defaults to 20 min.
  EOS
  task :check_for_downstream do
    downstream_url = ENV['DOWNSTREAM_JOB'] || raise('No ENV DOWNSTREAM_JOB set!')
    downstream_url += '/api/json?depth=1'
    expected_selector = ENV['BUILD_SELECTOR'] || raise('No ENV BUILD_SELECTOR set!')
    timeout = (ENV['TIMEOUT_MIN'] || 20) * 60
    puts "Waiting for a downstream job calling for BUILD_SELECTOR #{expected_selector}"
    success = false
    require 'json'
    require 'timeout'
    require 'net/http'
    Timeout.timeout(timeout) do
      loop do
        uri = URI(downstream_url)
        status = Net::HTTP.get(uri)
        json = JSON.parse(status)
        build_selector = get_parameter_value_from_actions(json['builds'].first['actions'], 'BUILD_SELECTOR')
        if build_selector < expected_selector && json['queueItem']
          queued_actions = json['queueItem']['actions']
          build_selector = get_parameter_value_from_actions(queued_actions, 'BUILD_SELECTOR') if queued_actions
        end
        puts " * downstream job's last build selector: #{build_selector}"
        break if build_selector >= expected_selector
        sleep 60
      end
    end
  end

  desc "Tar up the acceptance/ directory so that package test runs have tests to run against."
  task :acceptance_artifacts do
    sh "cd acceptance; rm -f acceptance-artifacts.tar.gz; tar -czv --exclude .bundle -f acceptance-artifacts.tar.gz *"
  end
end
