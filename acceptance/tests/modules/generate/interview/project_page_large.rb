test_name "puppet module generate interview - project page ascii string"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils
require 'json'

module_author = "foo"
module_name   = "bar"
module_dependencies = []

answer_project_page = File.read(File.join(File.dirname(__FILE__), 'mobydick.txt')).chomp

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '',
  :author        => '',
  :license       => '',
  :description   => '',
  :source        => '',
  :project       => answer_project_page,
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

    tmpdir = Dir.mktmpdir('metadata')
    scp_from(agent, "#{module_author}-#{module_name}/metadata.json", tmpdir)
    f = File.read("#{tmpdir}/metadata.json")
    json = JSON.parse(f)
    result = json['project_page']
    assert_equal(answer_project_page, result, 'project_page did not match expected')
  end

end
