test_name "puppet module generate interview creates README.md"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "foo"
module_name   = "bar"
module_readme = "#{module_author}-#{module_name}/README.md"
module_dependencies = []

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '',
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
    end
    answer_s = answer_a.join("\n") << "\n"
    tmpfile = agent.tmpfile('answers')
    create_remote_file(agent, tmpfile, answer_s)
    on(agent, puppet("module generate #{module_author}-#{module_name} < #{tmpfile}"))
  end

  step "Validate #{module_readme}" do
    on(agent, "test -f #{module_readme}")
    on(agent, "cat #{module_readme}") do |res|
      assert_match /# #{module_name}

#### Table of Contents

1. \[Overview\]\(#overview\)
2. \[Module Description - What the module does and why it is useful\]\(#module-description\)
3. \[Setup - The basics of getting started with #{module_name}\]\(#setup\)
    \* \[What #{module_name} affects\]\(#what-#{module_name}-affects\)
    \* \[Setup requirements\]\(#setup-requirements\)
    \* \[Beginning with #{module_name}\]\(#beginning-with-#{module_name}\)
4. \[Usage - Configuration options and additional functionality\]\(#usage\)
5. \[Reference - An under-the-hood peek at what the module is doing and how\]\(#reference\)
5. \[Limitations - OS compatibility, etc.\]\(#limitations\)
6. \[Development - Guide for contributing to the module\]\(#development\)
/m, res.stdout
    end
  end

end
