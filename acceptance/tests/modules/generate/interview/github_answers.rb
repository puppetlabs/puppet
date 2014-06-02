test_name "puppet module generate interview - github.com as source seeds project_page and issues_url"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = 'foo'
module_name   = 'bar'
module_source   = "https://github.com/#{module_author}/#{module_name}"
module_dependencies = []

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '',
  :author        => '',
  :license       => '',
  :description   => '',
  :source        => module_source,
  :project       => '',
  :issues        => '',
  :continue      => '',
}

agents.each do |agent|
  tmpfile = agent.tmpfile('answers')

  teardown do
    on(agent, "rm -rf #{module_author}-#{module_name}")
    on(agent, "rm -f #{tmpfile}")
  end

  step "Generate #{module_author}-#{module_name} module" do
    answer_a = []
    questions.each do |q|
      answer_a << answers[q]
    end
    answer_s = answer_a.join("\n") << "\n"
    tmpfile = agent.tmpfile('answers')
    create_remote_file(agent, tmpfile, answer_s)
    on(agent, puppet("module generate #{module_author}-#{module_name} < #{tmpfile}"))
  end

  step "Validate metadata.json for #{module_author}-#{module_name}" do
    on(agent, "test -f #{module_author}-#{module_name}/metadata.json")
    on(agent, "cat #{module_author}-#{module_name}/metadata.json") do |res|
      fail_test('not valid json') unless json_valid?(res.stdout)
      fail_test("source not #{module_source}") unless res.stdout.include? "\"source\": \"#{module_source}\""
      fail_test("project_page not based on github source #{module_source}") unless res.stdout.include? "\"project_page\": \"#{module_source}\""
      fail_test("issues_url not based on github source #{module_source}") unless res.stdout.include? "\"issues_url\": \"#{module_source}/issues\""
    end
  end

end
