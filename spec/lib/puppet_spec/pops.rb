module PuppetSpec::Pops
  extend RSpec::Matchers::DSL

  # Checks if an Acceptor has a specific issue in its list of diagnostics
  matcher :have_issue do |expected|
    match do |actual|
      actual.diagnostics.index { |i| i.issue == expected } != nil
    end
    failure_message do |actual|
      "expected Acceptor[#{actual.diagnostics.collect { |i| i.issue.issue_code }.join(',')}] to contain issue #{expected.issue_code}"
    end
    failure_message_when_negated do |actual|
      "expected Acceptor[#{actual.diagnostics.collect { |i| i.issue.issue_code }.join(',')}] to not contain issue #{expected.issue_code}"
    end
  end

  # Checks if an Acceptor has any issues
  matcher :have_any_issues do
    match do |actual|
      !actual.diagnostics.empty?
    end
    failure_message do |actual|
      'expected Acceptor[] to contain at least one issue'
    end
    failure_message_when_negated do |actual|
      "expected Acceptor[#{actual.diagnostics.collect { |i| i.issue.issue_code }.join(',')}] to not contain any issues"
    end
  end
end
