test_name "puppet module generate interview version invalid form - two dots"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "foo"
module_name   = "bar"
module_dependencies = []

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '..',
  :author        => '',
  :license       => '',
  :description   => '',
  :source        => '',
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
      break if q == :version
    end
    answer_s = answer_a.join("\n") << "\n" << "\n" << "\n" << "\n" << "\n" << "\n" << "\n" << "\n" << "\n" << "\n" << "\n"
    tmpfile = agent.tmpfile('answers')
    create_remote_file(agent, tmpfile, answer_s)
    on(agent, puppet("module generate #{module_author}-#{module_name} < #{tmpfile}")) do |res|
      fail_test('entry not rejected') unless res.stderr.match /not.*Semantic Version/
    end
  end

end
