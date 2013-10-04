Puppet::Face.define(:syntax, '1.0.0') do
  action :foo do
    when_invoked do |whom|
      "hello, #{whom}"
    end
  # This 'end' is deliberately omitted, to induce a syntax error.
  # Please don't fix that, as it is used for testing. --daniel 2011-05-02
end
