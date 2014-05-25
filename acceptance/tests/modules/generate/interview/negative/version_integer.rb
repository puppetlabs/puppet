test_name "puppet module generate interview version invalid form - integer"
skip_test "How to terminate module generate after answering version question?"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

ABORT = "\003"
module_author = "foo"
module_name   = "bar"
module_dependencies = []

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '10000',
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
    answer_s = answer_a.join("\n") << "\n" << ABORT
    tmpfile = agent.tmpfile('answers')
    create_remote_file(agent, tmpfile, answer_s)
    on(agent, puppet("module generate #{module_author}-#{module_name} < #{tmpfile}"), { :acceptable_exit_codes => [1] }) do |res|
      fail_test('entry not rejected') unless res.stdout.match /not.*Semantic Version/
    end
  end

  step "Validate #{module_author}-#{module_name} not created" do
    fail_test('not valid json') if File.exist? "#{module_author}-#{module_name}"
  end

end
