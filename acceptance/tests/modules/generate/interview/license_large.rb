test_name "puppet module generate interview - license ascii string"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = "foo"
module_name   = "bar"
module_dependencies = []

answer_license = File.read(File.join(File.dirname(__FILE__), 'mobydick.txt')).chomp

questions = [:version, :author, :license, :description, :source, :project, :issues, :continue]
answers = {
  :version       => '',
  :author        => '',
  :license       => answer_license,
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

  step "Validate metadata.json for #{module_author}-#{module_name}" do
    on(agent, "test -f #{module_author}-#{module_name}/metadata.json")
    on(agent, "cat #{module_author}-#{module_name}/metadata.json") do |res|
      fail_test('not valid json') unless json_valid?(res.stdout)
      result = /("license":.*)\n/.match(res.stdout)[1]
      result = result.chomp
      result = result.chomp(',')
      answer_license.gsub!('"', '\"')
      expected = "\"license\": \"#{answer_license}\""
      assert_equal(expected,result,'license did not match expected')
    end
  end

end
