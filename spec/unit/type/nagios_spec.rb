#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/external/nagios'

describe "Nagios parser" do

    NONESCAPED_SEMICOLON_COMMENT = <<-'EOL'
define host{
    use                     linux-server            ; Name of host template to use
    host_name               localhost
    alias                   localhost
    address                 127.0.0.1
    }

define command{
  command_name  notify-host-by-email
  command_line  /usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$
  }
EOL

    LINE_COMMENT_SNIPPET = <<-'EOL'

# This is a comment starting at the beginning of a line

define command{

# This is a comment starting at the beginning of a line

  command_name  command_name

# This is a comment starting at the beginning of a line
  ## --PUPPET_NAME-- (called '_naginator_name' in the manifest)                command_name

  command_line  command_line

# This is a comment starting at the beginning of a line

  }

# This is a comment starting at the beginning of a line

EOL

    LINE_COMMENT_SNIPPET2 = <<-'EOL'
      define host{
          use                     linux-server            ; Name of host template to use
          host_name               localhost
          alias                   localhost
          address                 127.0.0.1
          }
define command{
  command_name  command_name2
  command_line  command_line2
  }
EOL

    UNKNOWN_NAGIOS_OBJECT_DEFINITION = <<-'EOL'
      define command2{
        command_name  notify-host-by-email
        command_line  /usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$
        }
      EOL

    MISSING_CLOSING_CURLY_BRACKET = <<-'EOL'
      define command{
        command_name  notify-host-by-email
        command_line  /usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$
      EOL

    ESCAPED_SEMICOLON = <<-'EOL'
        define command {
            command_name  nagios_table_size
            command_line $USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\"\;" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$
        }
      EOL

    POUND_SIGN_HASH_SYMBOL_NOT_IN_FIRST_COLUMN = <<-'EOL'
        define command {
            command_name  notify-by-irc
            command_line /usr/local/bin/riseup-nagios-client.pl "$HOSTNAME$ ($SERVICEDESC$) $NOTIFICATIONTYPE$ #$SERVICEATTEMPT$ $SERVICESTATETYPE$ $SERVICEEXECUTIONTIME$s $SERVICELATENCY$s $SERVICEOUTPUT$ $SERVICEPERFDATA$"
        }
      EOL

    ANOTHER_ESCAPED_SEMICOLON = <<-EOL
define command {
\tcommand_line                   LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats\\;csv'
\tcommand_name                   check_haproxy
}
EOL

  it "should parse without error" do
    parser =  Nagios::Parser.new
    expect {
      results = parser.parse(NONESCAPED_SEMICOLON_COMMENT)
    }.to_not raise_error
  end

  describe "when parsing a statement" do
    parser =  Nagios::Parser.new
    results = parser.parse(NONESCAPED_SEMICOLON_COMMENT)
    results.each do |obj|
      it "should have the proper base type" do
        expect(obj).to be_a_kind_of(Nagios::Base)
      end
    end
  end

  it "should raise an error when an incorrect object definition is present" do
    parser =  Nagios::Parser.new
    expect {
      results = parser.parse(UNKNOWN_NAGIOS_OBJECT_DEFINITION)
    }.to raise_error Nagios::Base::UnknownNagiosType
  end

  it "should raise an error when syntax is not correct" do
    parser =  Nagios::Parser.new
    expect {
      results = parser.parse(MISSING_CLOSING_CURLY_BRACKET)
    }.to raise_error Nagios::Parser::SyntaxError
  end

  describe "when encoutering ';'" do
    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      expect {
        results = parser.parse(ESCAPED_SEMICOLON)
      }.to_not raise_error
    end

    it "should ignore it if it is a comment" do
      parser =  Nagios::Parser.new
      results = parser.parse(NONESCAPED_SEMICOLON_COMMENT)
      expect(results[0].use).to eql("linux-server")
    end

    it "should parse correctly if it is escaped" do
      parser =  Nagios::Parser.new
      results = parser.parse(ESCAPED_SEMICOLON)
      expect(results[0].command_line).to eql("$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name \"SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\\\"$ARG1$\\\";\" --name2 \"table size\" --units kBytes -w $ARG2$ -c $ARG3$")
    end
  end

  describe "when encountering '#'" do

    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      expect {
        results = parser.parse(POUND_SIGN_HASH_SYMBOL_NOT_IN_FIRST_COLUMN)
      }.to_not raise_error
    end


    it "should ignore it at the beginning of a line" do
      parser =  Nagios::Parser.new
      results = parser.parse(LINE_COMMENT_SNIPPET)
      expect(results[0].command_line).to eql("command_line")
    end

    it "should let it go anywhere else" do
      parser =  Nagios::Parser.new
      results = parser.parse(POUND_SIGN_HASH_SYMBOL_NOT_IN_FIRST_COLUMN)
      expect(results[0].command_line).to eql("/usr/local/bin/riseup-nagios-client.pl \"$HOSTNAME$ ($SERVICEDESC$) $NOTIFICATIONTYPE$ \#$SERVICEATTEMPT$ $SERVICESTATETYPE$ $SERVICEEXECUTIONTIME$s $SERVICELATENCY$s $SERVICEOUTPUT$ $SERVICEPERFDATA$\"")
    end

  end

  describe "when encountering ';' again" do
    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      expect {
        results = parser.parse(ANOTHER_ESCAPED_SEMICOLON)
      }.to_not raise_error
    end

    it "should parse correctly" do
      parser =  Nagios::Parser.new
      results = parser.parse(ANOTHER_ESCAPED_SEMICOLON)
      expect(results[0].command_line).to eql("LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats;csv'")
    end
  end


  it "should be idempotent" do
    parser =  Nagios::Parser.new
    src = ANOTHER_ESCAPED_SEMICOLON.dup
    results = parser.parse(src)
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_name = results[0].command_name
    nagios_type.command_line = results[0].command_line
    expect(nagios_type.to_s).to eql(ANOTHER_ESCAPED_SEMICOLON)
  end

end

describe "Nagios generator" do

  it "should escape ';'" do
    param = '$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\";" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$'
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    expect(nagios_type.to_s).to eql("define command {\n\tcommand_line                   $USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name \"SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\\\"$ARG1$\\\"\\;\" --name2 \"table size\" --units kBytes -w $ARG2$ -c $ARG3$\n}\n")
  end

  it "should escape ';' if it is not already the case" do
    param = "LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats;csv'"
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    expect(nagios_type.to_s).to eql("define command {\n\tcommand_line                   LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats\\;csv'\n}\n")
  end

  it "should be idempotent" do
    param = '$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\";" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$'
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    parser =  Nagios::Parser.new
    results = parser.parse(nagios_type.to_s)
    expect(results[0].command_line).to eql(param)
  end

  it "should accept FixNum params and convert to string" do
    param = 1
    nagios_type = Nagios::Base.create(:serviceescalation)
    nagios_type.first_notification = param
    parser =  Nagios::Parser.new
    results = parser.parse(nagios_type.to_s)
    expect(results[0].first_notification).to eql(param.to_s)
  end
end

describe "Nagios resource types" do
  Nagios::Base.eachtype do |name, nagios_type|
    puppet_type = Puppet::Type.type("nagios_#{name}")

    it "should have a valid type for #{name}" do
      expect(puppet_type).not_to be_nil
    end

    next unless puppet_type

    describe puppet_type do
      it "should be defined as a Puppet resource type" do
        expect(puppet_type).not_to be_nil
      end

      it "should have documentation" do
        expect(puppet_type.instance_variable_get("@doc")).not_to eq("")
      end

      it "should have #{nagios_type.namevar} as its key attribute" do
        expect(puppet_type.key_attributes).to eq([nagios_type.namevar])
      end

      it "should have documentation for its #{nagios_type.namevar} parameter" do
        expect(puppet_type.attrclass(nagios_type.namevar).instance_variable_get("@doc")).not_to be_nil
      end

      it "should have an ensure property" do
        expect(puppet_type).to be_validproperty(:ensure)
      end

      it "should have a target property" do
        expect(puppet_type).to be_validproperty(:target)
      end

      it "should have documentation for its target property" do
        expect(puppet_type.attrclass(:target).instance_variable_get("@doc")).not_to be_nil
      end

      [ :owner, :group, :mode ].each do |fileprop|
        it "should have a #{fileprop} parameter" do
          expect(puppet_type.parameters).to be_include(fileprop)
        end
      end

      nagios_type.parameters.reject { |param| param == nagios_type.namevar or param.to_s =~ /^[0-9]/ }.each do |param|
        it "should have a #{param} property" do
          expect(puppet_type).to be_validproperty(param)
        end

        it "should have documentation for its #{param} property" do
          expect(puppet_type.attrclass(param).instance_variable_get("@doc")).not_to be_nil
        end
      end

      nagios_type.parameters.find_all { |param| param.to_s =~ /^[0-9]/ }.each do |param|
        it "should have not have a #{param} property" do
          expect(puppet_type).not_to be_validproperty(:param)
        end
      end
    end
  end
end
