module PuppetTest::RailsTesting
  Parser = Puppet::Parser
  AST = Puppet::Parser::AST
  include PuppetTest::ParserTesting

  def teardown
    super

    # If we don't clean up the connection list, then the rails
    # lib will still think it's connected.
    ActiveRecord::Base.clear_active_connections! if Puppet.features.rails?
  end

  def railsinit
    Puppet::Rails.init
  end
end

