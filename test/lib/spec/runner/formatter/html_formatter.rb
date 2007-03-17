module Spec
  module Runner
    module Formatter
      class HtmlFormatter < BaseTextFormatter
        attr_reader :current_spec_number, :current_context_number
        
        def initialize(output, dry_run=false, colour=false)
          super
          @current_spec_number = 0
          @current_context_number = 0
        end

        def start(spec_count)
          @spec_count = spec_count

          @output.puts HEADER_1
          @output.puts extra_header_content unless extra_header_content.nil?
          @output.puts HEADER_2
          STDOUT.flush
        end

        def add_context(name, first)
          @current_context_number += 1
          unless first
            @output.puts "  </dl>"
            @output.puts "</div>"
          end
          @output.puts "<div class=\"context\">"
          @output.puts "  <dl>"
          @output.puts "  <dt id=\"context_#{@current_context_number}\">#{name}</dt>"
          STDOUT.flush
        end

        def start_dump
          @output.puts "  </dl>"
          @output.puts "</div>"
          STDOUT.flush
        end

        def spec_started(name)
          @current_spec_number += 1
          STDOUT.flush
        end

        def spec_passed(name)
          move_progress
          @output.puts "    <dd class=\"spec passed\"><span class=\"passed_spec_name\">#{escape(name)}</span></dd>"
          STDOUT.flush
        end

        def spec_failed(name, counter, failure)
          @output.puts "    <script type=\"text/javascript\">makeRed('header');</script>"
          @output.puts "    <script type=\"text/javascript\">makeRed('context_#{@current_context_number}');</script>"
          move_progress
          @output.puts "    <dd class=\"spec failed\">"
          @output.puts "      <span class=\"failed_spec_name\">#{escape(name)}</span>"
          @output.puts "      <div class=\"failure\" id=\"failure_#{counter}\">"
          @output.puts "        <div class=\"message\"><pre>#{escape(failure.exception.message)}</pre></div>" unless failure.exception.nil?
          @output.puts "        <div class=\"backtrace\"><pre>#{format_backtrace(failure.exception.backtrace)}</pre></div>" unless failure.exception.nil?
          @output.puts extra_failure_content unless extra_failure_content.nil?
          @output.puts "      </div>"
          @output.puts "    </dd>"
          STDOUT.flush
        end
        
        # Override this method if you wish to output extra HTML in the header
        #
        def extra_header_content
        end

        # Override this method if you wish to output extra HTML for a failed spec. For example, you
        # could output links to images or other files produced during the specs.
        #
        def extra_failure_content
        end
        
        def move_progress
          percent_done = @spec_count == 0 ? 100.0 : (@current_spec_number.to_f / @spec_count.to_f * 1000).to_i / 10.0
          @output.puts "    <script type=\"text/javascript\">moveProgressBar('#{percent_done}');</script>"
        end
        
        def escape(string)
          string.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
        end

        def dump_failure(counter, failure)
        end

        def dump_summary(duration, spec_count, failure_count)
          if @dry_run
            totals = "This was a dry-run"
          else
            totals = "#{spec_count} specification#{'s' unless spec_count == 1}, #{failure_count} failure#{'s' unless failure_count == 1}"
          end
          @output.puts "<script type=\"text/javascript\">document.getElementById('duration').innerHTML = \"Finished in <strong>#{duration} seconds</strong>\";</script>"
          @output.puts "<script type=\"text/javascript\">document.getElementById('totals').innerHTML = \"#{totals}\";</script>"
          @output.puts "</div>"
          @output.puts "</body>"
          @output.puts "</html>"
          STDOUT.flush
        end

        HEADER_1 = <<-EOF
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html
     PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>RSpec results</title>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
  <meta http-equiv="Expires" content="-1" />
  <meta http-equiv="Pragma" content="no-cache" />
EOF

        HEADER_2 = <<-EOF
  <script type="text/javascript">
  function moveProgressBar(percentDone) {
    document.getElementById("header").style.width = percentDone +"%";
  }
  function makeRed(element_id) {
    document.getElementById(element_id).style.background = '#C40D0D';
  }
  </script>
  <style type="text/css">
  body {
    margin: 0; padding: 0;
    background: #fff;
  }

  #header {
    background: #65C400; color: #fff;
  }

  h1 {
    margin: 0 0 10px;
    padding: 10px;
    font: bold 18px "Lucida Grande", Helvetica, sans-serif;
  }

  #summary {
    margin: 0; padding: 5px 10px;
    font: bold 10px "Lucida Grande", Helvetica, sans-serif;
    text-align: right;
    position: absolute;
    top: 0px;
    right: 0px;
  }

  #summary p {
    margin: 0 0 2px;
  }

  #summary #totals {
    font-size: 14px;
  }

  .context {
    margin: 0 10px 5px;
    background: #fff;
  }

  dl {
    margin: 0; padding: 0 0 5px;
    font: normal 11px "Lucida Grande", Helvetica, sans-serif;
  }

  dt {
    padding: 3px;
    background: #65C400;
    color: #fff;
    font-weight: bold;
  }

  dd {
    margin: 5px 0 5px 5px;
    padding: 3px 3px 3px 18px;
  }

  dd.spec.passed {
    border-left: 5px solid #65C400;
    border-bottom: 1px solid #65C400;
    background: #DBFFB4; color: #3D7700;
  }

  dd.spec.failed {
    border-left: 5px solid #C20000;
    border-bottom: 1px solid #C20000;
    color: #C20000; background: #FFFBD3;
  }

  div.backtrace {
    color: #000;
    font-size: 12px;
  }

  a {
    color: #BE5C00;
  }
  </style>
</head>
<body>

<div id="header">
  <h1>RSpec Results</h1>

  <div id="summary">
    <p id="duration">&nbsp;</p>
    <p id="totals">&nbsp;</p>
  </div>
</div>

<div id="results">
EOF
      end
    end
  end
end
