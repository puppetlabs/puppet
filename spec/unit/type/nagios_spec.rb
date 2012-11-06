#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/external/nagios'

describe "Nagios parser" do

  before do

    @snippet = <<-'EOL'
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

    @line_comment_snippet = <<-'EOL'

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

    @line_comment_snippet2 = <<-'EOL'
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

    @bad_snippet = <<-'EOL'
      define command2{
        command_name  notify-host-by-email
        command_line  /usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$
        }
      EOL

    @bad_snippet2 = <<-'EOL'
      define command{
        command_name  notify-host-by-email
        command_line  /usr/bin/printf "%b" "***** Nagios *****\n\nNotification Type: $NOTIFICATIONTYPE$\nHost: $HOSTNAME$\nState: $HOSTSTATE$\nAddress: $HOSTADDRESS$\nInfo: $HOSTOUTPUT$\n\nDate/Time: $LONGDATETIME$\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$ **" $CONTACTEMAIL$
      EOL

    @regression1 = <<-'EOL'
        define command {
            command_name  nagios_table_size
            command_line $USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\"\;" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$
        }
      EOL

    @regression2 = <<-'EOL'
        define command {
            command_name  notify-by-irc
            command_line /usr/local/bin/riseup-nagios-client.pl "$HOSTNAME$ ($SERVICEDESC$) $NOTIFICATIONTYPE$ #$SERVICEATTEMPT$ $SERVICESTATETYPE$ $SERVICEEXECUTIONTIME$s $SERVICELATENCY$s $SERVICEOUTPUT$ $SERVICEPERFDATA$"
        }
      EOL

    @regression3 = <<-EOL
define command {
\tcommand_name                   check_haproxy
\tcommand_line                   LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats\\;csv'
}
EOL
  end

  it "should parse without error" do
    parser =  Nagios::Parser.new
    lambda {
      results = parser.parse(@snippet)
    }.should_not raise_error
  end

  it "should have the proper base type" do
    parser =  Nagios::Parser.new
    results = parser.parse(@snippet)
    results.each do |obj|

      describe "should parse correctly" do
        it "should work" do
            obj.should be_a_kind_of(Nagios::Base)
        end
      end
    end
  end

  it "should raise an error when an incorrect command is present" do
    parser =  Nagios::Parser.new
    lambda {
      results = parser.parse(@bad_snippet)
    }.should raise_error Nagios::Base::UnknownNagiosType
  end

  it "should raise an error when syntax is not correct" do
    parser =  Nagios::Parser.new
    lambda {
      results = parser.parse(@bad_snippet2)
    }.should raise_error Nagios::Parser::SyntaxError
  end

  describe "when encoutering ';'" do
    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      lambda {
        results = parser.parse(@regression1)
      }.should_not raise_error Nagios::Parser::SyntaxError
    end

    it "should ignore it if it is a comment" do
      parser =  Nagios::Parser.new
      results = parser.parse(@snippet)
      results[0].use.should eql("linux-server")
    end

    it "should parse correctly if it is escaped" do
      parser =  Nagios::Parser.new
      results = parser.parse(@regression1)
      results[0].command_line.should eql("$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name \"SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\\\"$ARG1$\\\";\" --name2 \"table size\" --units kBytes -w $ARG2$ -c $ARG3$")
    end
  end

  describe "when encoutering '#'" do

    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      lambda {
        results = parser.parse(@regression2)
      }.should_not raise_error Nagios::Parser::SyntaxError
    end


    it "should ignore it at the beginning of a line" do
      parser =  Nagios::Parser.new
      results = parser.parse(@line_comment_snippet)
      results[0].command_line.should eql("command_line")
    end

    it "should let it go anywhere else" do
      parser =  Nagios::Parser.new
      results = parser.parse(@regression2)
      results[0].command_line.should eql("/usr/local/bin/riseup-nagios-client.pl \"$HOSTNAME$ ($SERVICEDESC$) $NOTIFICATIONTYPE$ \#$SERVICEATTEMPT$ $SERVICESTATETYPE$ $SERVICEEXECUTIONTIME$s $SERVICELATENCY$s $SERVICEOUTPUT$ $SERVICEPERFDATA$\"")
    end

  end

  describe "when encountering ';' again" do
    it "should not throw an exception" do
      parser =  Nagios::Parser.new
      lambda {
        results = parser.parse(@regression3)
      }.should_not raise_error Nagios::Parser::SyntaxError
    end

    it "should parse correctly" do
      parser =  Nagios::Parser.new
      results = parser.parse(@regression3)
      results[0].command_line.should eql("LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats;csv'")
    end
  end


  it "should be idempotent" do
    parser =  Nagios::Parser.new
    src = @regression3.dup
    results = parser.parse(src)
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_name = results[0].command_name
    nagios_type.command_line = results[0].command_line
    nagios_type.to_s.should eql(@regression3)
  end

end

describe "Nagios generator" do

  it "should escape ';'" do
    param = '$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\";" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$'
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    nagios_type.to_s.should eql("define command {\n\tcommand_line                   $USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name \"SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\\\"$ARG1$\\\"\\;\" --name2 \"table size\" --units kBytes -w $ARG2$ -c $ARG3$\n}\n")
  end

  it "should escape ';' if it is not already the case" do
    param = "LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats;csv'"
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    nagios_type.to_s.should eql("define command {\n\tcommand_line                   LC_ALL=en_US.UTF-8 /usr/lib/nagios/plugins/check_haproxy -u 'http://blah:blah@$HOSTADDRESS$:8080/haproxy?stats\\;csv'\n}\n")
  end

  it "should be idempotent" do
    param = '$USER3$/check_mysql_health --hostname localhost --username nagioschecks --password nagiosCheckPWD --mode sql --name "SELECT ROUND(Data_length/1024) as Data_kBytes from INFORMATION_SCHEMA.TABLES where TABLE_NAME=\"$ARG1$\";" --name2 "table size" --units kBytes -w $ARG2$ -c $ARG3$'
    nagios_type = Nagios::Base.create(:command)
    nagios_type.command_line = param
    parser =  Nagios::Parser.new
    results = parser.parse(nagios_type.to_s)
    results[0].command_line.should eql(param)
  end
end

describe "Nagios resource types" do
  Nagios::Base.eachtype do |name, nagios_type|
    puppet_type = Puppet::Type.type("nagios_#{name}")

    it "should have a valid type for #{name}" do
      puppet_type.should_not be_nil
    end

    next unless puppet_type

    describe puppet_type do
      it "should be defined as a Puppet resource type" do
        puppet_type.should_not be_nil
      end

      it "should have documentation" do
        puppet_type.instance_variable_get("@doc").should_not == ""
      end

      it "should have #{nagios_type.namevar} as its key attribute" do
        puppet_type.key_attributes.should == [nagios_type.namevar]
      end

      it "should have documentation for its #{nagios_type.namevar} parameter" do
        puppet_type.attrclass(nagios_type.namevar).instance_variable_get("@doc").should_not be_nil
      end

      it "should have an ensure property" do
        puppet_type.should be_validproperty(:ensure)
      end

      it "should have a target property" do
        puppet_type.should be_validproperty(:target)
      end

      it "should have documentation for its target property" do
        puppet_type.attrclass(:target).instance_variable_get("@doc").should_not be_nil
      end

      nagios_type.parameters.reject { |param| param == nagios_type.namevar or param.to_s =~ /^[0-9]/ }.each do |param|
        it "should have a #{param} property" do
          puppet_type.should be_validproperty(param)
        end

        it "should have documentation for its #{param} property" do
          puppet_type.attrclass(param).instance_variable_get("@doc").should_not be_nil
        end
      end

      nagios_type.parameters.find_all { |param| param.to_s =~ /^[0-9]/ }.each do |param|
        it "should have not have a #{param} property" do
          puppet_type.should_not be_validproperty(:param)
        end
      end
    end
  end
end
