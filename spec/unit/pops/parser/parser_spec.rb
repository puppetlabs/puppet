require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Parser::Parser do
  it "should instantiate a parser" do
    parser = Puppet::Pops::Parser::Parser.new()
    expect(parser.class).to eq(Puppet::Pops::Parser::Parser)
  end

  it "should parse a code string and return a model" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("$a = 10").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::AssignmentExpression)
  end

  it "should accept empty input and return a model" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
  end

  it "should accept empty input containing only comments and report location at end of input" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# comment\n").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
    expect(model.body.offset).to eq(10)
    expect(model.body.length).to eq(0)
  end

  it "should give single resource expressions the correct offset inside an if/else statement" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string(<<-EOF).model
class firewall {
  if(true) {
    service { 'if service':
      ensure    => stopped
    }
  } else {
    service { 'else service':
      ensure    => running
    }
  }
}
    EOF

    then_service = model.body.body.statements[0].then_expr
    expect(then_service.class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(then_service.offset).to eq(34)

    else_service = model.body.body.statements[0].else_expr
    expect(else_service.class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(else_service.offset).to eq(106)
  end

  it "should give block expressions and their contained resources the correct offset inside an if/else statement" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string(<<-EOF).model
class firewall {
  if(true) {
    service { 'if service 1':
      ensure    => running
    }

    service { 'if service 2':
      ensure    => stopped
    }
  } else {
    service { 'else service 1':
      ensure    => running
    }

    service { 'else service 2':
      ensure    => stopped
    }
  }
}
    EOF

    if_expr = model.body.body.statements[0]
    block_expr = model.body.body.statements[0].then_expr
    expect(if_expr.class).to eq(Puppet::Pops::Model::IfExpression)
    expect(if_expr.offset).to eq(19)
    expect(block_expr.class).to eq(Puppet::Pops::Model::BlockExpression)
    expect(block_expr.offset).to eq(28)
    expect(block_expr.statements[0].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[0].offset).to eq(34)
    expect(block_expr.statements[1].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[1].offset).to eq(98)

    block_expr = model.body.body.statements[0].else_expr
    expect(block_expr.class).to eq(Puppet::Pops::Model::BlockExpression)
    expect(block_expr.offset).to eq(166)
    expect(block_expr.statements[0].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[0].offset).to eq(172)
    expect(block_expr.statements[1].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[1].offset).to eq(238)
  end

  it "should give single resource expressions the correct offset inside an unless/else statement" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string(<<-EOF).model
class firewall {
  unless(true) {
    service { 'if service':
      ensure    => stopped
    }
  } else {
    service { 'else service':
      ensure    => running
    }
  }
}
    EOF

    then_service = model.body.body.statements[0].then_expr
    expect(then_service.class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(then_service.offset).to eq(38)

    else_service = model.body.body.statements[0].else_expr
    expect(else_service.class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(else_service.offset).to eq(110)
  end

  it "should give block expressions and their contained resources the correct offset inside an unless/else statement" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string(<<-EOF).model
class firewall {
  unless(true) {
    service { 'if service 1':
      ensure    => running
    }

    service { 'if service 2':
      ensure    => stopped
    }
  } else {
    service { 'else service 1':
      ensure    => running
    }

    service { 'else service 2':
      ensure    => stopped
    }
  }
}
    EOF

    if_expr = model.body.body.statements[0]
    block_expr = model.body.body.statements[0].then_expr
    expect(if_expr.class).to eq(Puppet::Pops::Model::UnlessExpression)
    expect(if_expr.offset).to eq(19)
    expect(block_expr.class).to eq(Puppet::Pops::Model::BlockExpression)
    expect(block_expr.offset).to eq(32)
    expect(block_expr.statements[0].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[0].offset).to eq(38)
    expect(block_expr.statements[1].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[1].offset).to eq(102)

    block_expr = model.body.body.statements[0].else_expr
    expect(block_expr.class).to eq(Puppet::Pops::Model::BlockExpression)
    expect(block_expr.offset).to eq(170)
    expect(block_expr.statements[0].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[0].offset).to eq(176)
    expect(block_expr.statements[1].class).to eq(Puppet::Pops::Model::ResourceExpression)
    expect(block_expr.statements[1].offset).to eq(242)
  end

  it "multi byte characters in a comment are counted as individual bytes" do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string("# \u{0400}comment\n").model
    expect(model.class).to eq(Puppet::Pops::Model::Program)
    expect(model.body.class).to eq(Puppet::Pops::Model::Nop)
    expect(model.body.offset).to eq(12)
    expect(model.body.length).to eq(0)
  end

  it "should raise an error with position information when error is raised from within parser" do
    parser = Puppet::Pops::Parser::Parser.new()
    the_error = nil
    begin
      parser.parse_string("File [1] { }", 'fakefile.pp')
    rescue Puppet::ParseError => e
      the_error = e
    end
    expect(the_error).to be_a(Puppet::ParseError)
    expect(the_error.file).to eq('fakefile.pp')
    expect(the_error.line).to eq(1)
    expect(the_error.pos).to eq(6)
  end

  it "should raise an error with position information when error is raised on token" do
    parser = Puppet::Pops::Parser::Parser.new()
    the_error = nil
    begin
      parser.parse_string(<<-EOF, 'fakefile.pp')
class whoops($a,$b,$c) {
  $d = "oh noes",  "b"
}
      EOF
    rescue Puppet::ParseError => e
      the_error = e
    end
    expect(the_error).to be_a(Puppet::ParseError)
    expect(the_error.file).to eq('fakefile.pp')
    expect(the_error.line).to eq(2)
    expect(the_error.pos).to eq(17)
  end
end
