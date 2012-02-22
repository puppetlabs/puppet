test_name "#12572: Don't print a diff for last_run_summary when show_diff is on"

agents.each do |host|
  # Have to run apply twice in order to make sure a diff would be relevant
  on host, puppet_apply("--verbose --show_diff"), :stdin => "notice 'hello'"
  on host, puppet_apply("--verbose --show_diff"), :stdin => "notice 'hello'" do
    assert_no_match(/notice:.*last_run_summary/, stdout, "should not show a diff for last_run_summary")
  end
end
