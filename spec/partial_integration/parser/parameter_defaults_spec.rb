require 'spec_helper'
require 'puppet_spec/language'

['Function', 'EPP'].each do |call_type|
  describe "#{call_type} parameter default expressions" do
    let! (:func_bodies) {
      [
        '{}',
        '{ notice("\$a == ${a}") }',
        '{ notice("\$a == ${a}") notice("\$b == ${b}") }',
        '{ notice("\$a == ${a}") notice("\$b == ${b}")  notice("\$c == ${c}") }'
      ]
    }

    let! (:epp_bodies) {
      [
        '',
        '<% notice("\$a == ${a}") %>',
        '<% notice("\$a == ${a}") notice("\$b == ${b}") %>',
        '<% notice("\$a == ${a}") notice("\$b == ${b}")  notice("\$c == ${c}") %>'
      ]
    }
    let! (:param_names) {  ('a'..'c').to_a }

    let (:call_type) { call_type }

    let (:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new('specification')) }

    let (:topscope) { compiler.topscope }

    def collect_notices(code)
      logs = []
      Puppet[:code] = code
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compiler.compile do |catalog|
            yield
            catalog
          end
      end
      logs.select { |log| log.level == :notice }.map { |log| log.message }
    end

    # @param arg_list [String] comma separated parameter declarations. Not enclosed in parenthesis
    # @param body [String,Integer] verbatim body or index of an entry in func_bodies
    # @param call_params [Array[#to_s]] array of call parameters
    # @return [Array] array of notice output entries
    #
    def eval_collect_notices(arg_list, body, call_params)
      call = call_params.is_a?(String) ? call_params : "example(#{call_params.map {|p| p.nil? ? 'undef' : (p.is_a?(String) ? "'#{p}'" : p )}.join(',')})"
      body = func_bodies[body] if body.is_a?(Integer)
      evaluator = Puppet::Pops::Parser::EvaluatingParser.new()
      collect_notices("function example(#{arg_list}) #{body}") do
        evaluator.evaluate_string(compiler.topscope, call)
      end
    end

    # @param arg_list [String] comma separated parameter declarations. Not enclosed in parenthesis
    # @param body [String,Integer] verbatim body or index of an entry in bodies
    # @param call_params [Array] array of call parameters
    # @param code [String] code to evaluate
    # @return [Array] array of notice output entries
    #
    def epp_eval_collect_notices(arg_list, body, call_params, code, inline_epp)
      body = body.is_a?(Integer) ? epp_bodies[body] : body.strip
      source = "<%| #{arg_list} |%>#{body}"
      named_params = call_params.reduce({}) {|h, v| h[param_names[h.size]] = v; h }
      collect_notices(code) do
        if inline_epp
          Puppet::Pops::Evaluator::EppEvaluator.inline_epp(compiler.topscope, source, named_params)
        else
          file = Tempfile.new(['epp-script', '.epp'])
          begin
            file.write(source)
            file.close
            Puppet::Pops::Evaluator::EppEvaluator.epp(compiler.topscope, file.path, 'test', named_params)
          ensure
            file.unlink
          end
        end
      end
    end


    # evaluates a function or EPP call, collects notice output in a log and compares log to expected result
    #
    # @param decl [Array[]] two element array with argument list declaration and body. Body can a verbatim string
    #   or an integer index of an entry in bodies
    # @param call_params [Array[#to_s]] array of call parameters
    # @param code [String] code to evaluate. Only applicable when call_type == 'EPP'
    # @param inline_epp [Boolean] true for inline_epp, false for file based epp, Only applicable when call_type == 'EPP'
    # @return [Array] array of notice output entries
    #
    def expect_log(decl, call_params, result, code = 'undef', inline_epp = true)
      if call_type == 'Function'
        expect(eval_collect_notices(decl[0], decl[1], call_params)).to include(*result)
      else
        expect(epp_eval_collect_notices(decl[0], decl[1], call_params, code, inline_epp)).to include(*result)
      end
    end

    # evaluates a function or EPP call and expects a failure
    #
    # @param decl [Array[]] two element array with argument list declaration and body. Body can a verbatim string
    #   or an integer index of an entry in bodies
    # @param call_params [Array[#to_s]] array of call parameters
    # @param text [String,Regexp] expected error message
    def expect_fail(decl, call, text, inline_epp = true)
      if call_type == 'Function'
        expect{eval_collect_notices(decl[0], decl[1], call) }.to raise_error(StandardError, text)
      else
        expect{epp_eval_collect_notices(decl[0], decl[1], call, 'undef', inline_epp) }.to raise_error(StandardError, text)
      end
    end

    context 'that references a parameter to the left that has no default' do
      let!(:params) { [ <<-SOURCE, 2 ]
      $a,
      $b = $a
      SOURCE
      }

      it 'fails when no value is provided for required first parameter', :if => call_type == 'Function' do
        expect_fail(params, [], /expects between 1 and 2 arguments, got none/)
      end

      it 'fails when no value is provided for required first parameter', :if => call_type == 'EPP' do
        expect_fail(params, [], /expects a value for parameter \$a/)
      end

      it "will use the referenced parameter's given value" do
        expect_log(params, [2], ['$a == 2', '$b == 2'])
      end

      it 'will not be evaluated when a value is given' do
        expect_log(params, [2, 5], ['$a == 2', '$b == 5'])
      end
    end

    context 'that references a parameter to the left that has a default' do
      let!(:params) { [ <<-SOURCE, 2 ]
      $a = 10,
      $b = $a
      SOURCE
      }

      it "will use the referenced parameter's default value when no value is given for the referenced parameter" do
        expect_log(params, [], ['$a == 10', '$b == 10'])
      end

      it "will use the referenced parameter's given value" do
        expect_log(params, [2], ['$a == 2', '$b == 2'])
      end

      it 'will not be evaluated when a value is given' do
        expect_log(params, [2, 5], ['$a == 2', '$b == 5'])
      end
    end

    context 'that references a variable to the right' do
      let!(:params) { [ <<-SOURCE, 3 ]
      $a = 10,
      $b = $c,
      $c = 20
      SOURCE
      }

      it 'fails when the reference is evaluated' do
        expect_fail(params, [1], /default expression for \$b tries to illegally access not yet evaluated \$c/)
      end

      it 'does not fail when a value is given for the culprit parameter' do
        expect_log(params, [1,2], ['$a == 1', '$b == 2', '$c == 20'])
      end

      it 'does not fail when all values are given' do
        expect_log(params, [1,2,3], ['$a == 1', '$b == 2', '$c == 3'])
      end
    end

    context 'with regular expressions' do
      it "evaluates unset match scope parameter's to undef" do
        expect_log([<<-SOURCE, 2], [], ['$a == ', '$b == '])
        $a = $0,
        $b = $1
        SOURCE
      end

      it 'does not leak match variables from one expression to the next' do
        expect_log([<<-SOURCE, 2], [], ['$a == [true, h, ello]', '$b == '])
        $a = ['hello' =~ /(h)(.*)/, $1, $2],
        $b = $1
        SOURCE
      end

      it 'can evaluate expressions in separate match scopes' do
        expect_log([<<-SOURCE, 3], [], ['$a == [true, h, ell, o]', '$b == [true, h, i, ]', '$c == '])
        $a = ['hello' =~ /(h)(.*)(o)/, $1, $2, $3],
        $b = ['hi' =~ /(h)(.*)/, $1, $2, $3],
        $c = $1
        SOURCE
      end

      it 'can have nested match expressions' do
        expect_log([<<-SOURCE, 2], [], ['$a == [true, h, oo, h, i]', '$b == '] )
        $a = ['hi' =~ /(h)(.*)/, $1, if'foo' =~ /f(oo)/ { $1 }, $1, $2],
        $b = $0
        SOURCE
      end

      it 'can not see match scope from calling scope', :if => call_type == 'Function' do
        expect_log([<<-SOURCE, <<-BODY], <<-CALL, ['$a == '])
        $a = $0
        SOURCE
        {
          notice("\\$a == ${a}")
        }
        function caller() {
          example()
        }
        BODY
        $tmp = 'foo' =~ /(f)(o)(o)/
        caller()
        CALL
      end

      context 'matches in calling scope', :if => call_type == 'EPP' do
        it 'are available when using inlined epp' do
          # Note that CODE is evaluated before the EPP is evaluated
          #
          expect_log([<<-SOURCE, <<-BODY], [], ['$ax == true', '$bx == foo'], <<-CODE, true)
          $a = $tmp,
          $b = $0
          SOURCE
          <% called_from_template($a, $b) %>
          BODY
          function called_from_template($ax, $bx) {
            notice("\\$ax == $ax")
            notice("\\$bx == $bx")
          }
          $tmp = 'foo' =~ /(f)(o)(o)/
          CODE
        end

        it 'are not available when using epp file' do
          # Note that CODE is evaluated before the EPP is evaluated
          #
          expect_log([<<-SOURCE, <<-BODY], [], ['$ax == true', '$bx == '], <<-CODE, false)
          $a = $tmp,
          $b = $0
            SOURCE
          <% called_from_template($a, $b) %>
            BODY
          function called_from_template($ax, $bx) {
            notice("\\$ax == $ax")
            notice("\\$bx == $bx")
          }
          $tmp = 'foo' =~ /(f)(o)(o)/
          CODE
        end
      end


      it 'will allow nested lambdas to access enclosing match scope' do
        expect_log([<<-SOURCE, 1], [], ['$a == [1-ello, 2-ello, 3-ello]'])
        $a = case "hello" {
          /(h)(.*)/ : {
            [1,2,3].map |$x| { "$x-$2" }
          }
        }
        SOURCE
      end

      it "will not make match scope available to #{call_type} body" do
        expect_log([<<-SOURCE, call_type == 'Function' ? <<-BODY : <<-EPP_BODY], [], ['Yes'])
        $a = "hello" =~ /.*/
        SOURCE
        {
          notice("Y${0}es")
        }
        BODY
        <%
          notice("Y${0}es")
        %>
        EPP_BODY
      end

      it 'can access earlier match results when produced using the match function' do
        expect_log([<<-SOURCE, 3], [], ['$a == [hello, h, ello]', '$b == hello', '$c == h'])
        $a = 'hello'.match(/(h)(.*)/),
        $b = $a[0],
        $c = $a[1]
        SOURCE
      end
    end


    context 'will not permit assignments' do
      it 'at top level' do
        expect_fail([<<-SOURCE, 0], [], /Syntax error at '='/)
        $a = $x = $0
        SOURCE
      end

      it 'in arrays' do
        expect_fail([<<-SOURCE, 0], [], /Assignment not allowed here/)
        $a = [$x = 3]
        SOURCE
      end

      it 'of variable with the same name as a subsequently declared parameter' do
        expect_fail([<<-SOURCE, 0], [], /Assignment not allowed here/)
        $a = ($b = 3),
        $b = 5
        SOURCE
      end

      it 'of variable with the same name as a previously declared parameter' do
        expect_fail([<<-SOURCE, 0], [], /Assignment not allowed here/)
        $a = 10,
        $b = ($a = 10)
        SOURCE
      end
    end

    it 'will permit assignments in nested scope' do
      expect_log([<<-SOURCE, 3], [], ['$a == [1, 2, 3]', '$b == 0', '$c == [6, 12, 18]'])
      $a = [1,2,3],
      $b = 0,
      $c = $a.map |$x| { $b = $x; $b * $a.reduce |$x, $y| {$x + $y} }
      SOURCE
    end

    it 'will not permit duplicate parameter names' do
      expect_fail([<<-SOURCE, 0], [], /The parameter 'a' is declared more than once/ )
      $a = 2,
      $a = 5
      SOURCE
    end

    it 'will permit undef for optional parameters' do
      expect_log([<<-SOURCE, 1], [nil], ['$a == '])
      Optional[Integer] $a
      SOURCE
    end

    it 'undef will override parameter default', :if => call_type == 'Function' do
      expect_log([<<-SOURCE, 1], [nil], ['$a == '])
      Optional[Integer] $a = 4
      SOURCE
    end

    it 'undef will not override parameter default', :unless => call_type == 'Function' do
      expect_log([<<-SOURCE, 1], [nil], ['$a == 4'])
      Optional[Integer] $a = 4
      SOURCE
    end
  end
end
