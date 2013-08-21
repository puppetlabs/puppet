#
# = CSS2 RDoc HTML template
#
# This is a template for RDoc that uses XHTML 1.0 Transitional and dictates a
# bit more of the appearance of the output to cascading stylesheets than the
# default. It was designed for clean inline code display, and uses DHTMl to
# toggle the visbility of each method's source with each click on the '[source]'
# link.
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
#
# Copyright (c) 2002, 2003 The FaerieMUD Consortium. Some rights reserved.
#
# This work is licensed under the Creative Commons Attribution License. To view
# a copy of this license, visit http://creativecommons.org/licenses/by/1.0/ or
# send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California
# 94305, USA.
#

module RDoc
  module Page

    FONTS = "Verdana,Arial,Helvetica,sans-serif"

STYLE = %{
/* Reset */
html,body,div,span,applet,object,iframe,h1,h2,h3,h4,h5,h6,p,blockquote,pre,a,abbr,acronym,address,big,cite,code,del,dfn,em,font,img,ins,kbd,q,s,samp,small,strike,strong,sub,sup,tt,var,dl,dt,dd,ol,ul,li,fieldset,form,label,legend,table,caption,tbody,tfoot,thead,tr,th,td{margin:0;padding:0;border:0;outline:0;font-weight:inherit;font-style:inherit;font-size:100%;font-family:inherit;vertical-align:baseline;}
:focus{outline:0;}
body{line-height:1;color:#282828;background:#fff;}
ol,ul{list-style:none;}
table{border-collapse:separate;border-spacing:0;}
caption,th,td{text-align:left;font-weight:normal;}
blockquote:before,blockquote:after,q:before,q:after{content:"";}
blockquote,q{quotes:"""";}

body {
    font-family: Verdana,Arial,Helvetica,sans-serif;
    font-size: 0.9em;
}

pre {
    background: none repeat scroll 0 0 #F7F7F7;
    border: 1px dashed #DDDDDD;
    color: #555555;
    font-family: courier;
    margin: 10px 19px;
    padding: 10px;
 }

h1,h2,h3,h4 { margin: 0; color: #efefef; background: transparent; }
h1 { font-size: 1.2em; }
h2,h3,h4 { margin-top: 1em; color:#558; }
h2,h3 { font-size: 1.1em; }

a { color: #037; text-decoration: none; }
a:hover { color: #04d; }

/* Override the base stylesheet's Anchor inside a table cell */
td > a {
  background: transparent;
  color: #039;
  text-decoration: none;
}

/* and inside a section title */
.section-title > a {
  background: transparent;
  color: #eee;
  text-decoration: none;
}

/* === Structural elements =================================== */

div#index {
    padding: 0;
}


div#index a {
	display:inline-block;
	padding:2px 10px;
}


div#index .section-bar {
	background: #ffe;
	padding:10px;
}


div#classHeader, div#fileHeader {
    border-bottom: 1px solid #ddd;
	padding:10px;
	font-size:0.9em;
}

div#classHeader a, div#fileHeader a {
    background: inherit;
    color: white;
}

div#classHeader td, div#fileHeader td {
    color: white;
	padding:3px;
	font-size:0.9em;
}


div#fileHeader {
    background: #057;
}

div#classHeader {
    background: #048;
}

div#nodeHeader {
    background: #7f7f7f;
}

.class-name-in-header {
  font-weight: bold;
}


div#bodyContent {
    padding: 10px;
}

div#description {
    padding: 10px;
    background: #f5f5f5;
    border: 1px dotted #ddd;
	line-height:1.2em;
}

div#description h1,h2,h3,h4,h5,h6 {
    color: #125;;
    background: transparent;
}

div#validator-badges {
    text-align: center;
}
div#validator-badges img { border: 0; }

div#copyright {
    color: #333;
    background: #efefef;
    font: 0.75em sans-serif;
    margin-top: 5em;
    margin-bottom: 0;
    padding: 0.5em 2em;
}


/* === Classes =================================== */

table.header-table {
    color: white;
    font-size: small;
}

.type-note {
    font-size: small;
    color: #DEDEDE;
}

.xxsection-bar {
    background: #eee;
    color: #333;
    padding: 3px;
}

.section-bar {
   color: #333;
   border-bottom: 1px solid #ddd;
   padding:10px 0;
   margin:5px 0 10px 0;
}

div#class-list, div#methods, div#includes, div#resources, div#requires, div#realizes, div#attribute-list { padding:10px; }

.section-title {
    background: #79a;
    color: #eee;
    padding: 3px;
    margin-top: 2em;
    border: 1px solid #999;
}

.top-aligned-row {  vertical-align: top }
.bottom-aligned-row { vertical-align: bottom }

/* --- Context section classes ----------------------- */

.context-row { }
.context-item-name { font-family: monospace; font-weight: bold; color: black; }
.context-item-value { font-size: small; color: #448; }
.context-item-desc { color: #333; padding-left: 2em; }

/* --- Method classes -------------------------- */
.method-detail {
    background: #f5f5f5;
}
.method-heading {
  color: #333;
  font-style:italic;
  background: #ddd;
  padding:5px 10px;
}
.method-signature { color: black; background: inherit; }
.method-name { font-weight: bold; }
.method-args { font-style: italic; }
.method-description { padding: 10px 10px 20px 10px; }

/* --- Source code sections -------------------- */

a.source-toggle { font-size: 90%; }
div.method-source-code {
    background: #262626;
    color: #ffdead;
    margin: 1em;
    padding: 0.5em;
    border: 1px dashed #999;
    overflow: hidden;
}

div.method-source-code pre { color: #ffdead; overflow: hidden; }

/* --- Ruby keyword styles --------------------- */

.standalone-code { background: #221111; color: #ffdead; overflow: hidden; }

.ruby-constant  { color: #7fffd4; background: transparent; }
.ruby-keyword { color: #00ffff; background: transparent; }
.ruby-ivar    { color: #eedd82; background: transparent; }
.ruby-operator  { color: #00ffee; background: transparent; }
.ruby-identifier { color: #ffdead; background: transparent; }
.ruby-node    { color: #ffa07a; background: transparent; }
.ruby-comment { color: #b22222; font-weight: bold; background: transparent; }
.ruby-regexp  { color: #ffa07a; background: transparent; }
.ruby-value   { color: #7fffd4; background: transparent; }
}


#####################################################################
### H E A D E R   T E M P L A T E
#####################################################################

XHTML_PREAMBLE = %{<?xml version="1.0" encoding="%charset%"?>
<!DOCTYPE html
     PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
}

HEADER = XHTML_PREAMBLE + %{
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>%title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
  <meta http-equiv="Content-Script-Type" content="text/javascript" />
  <link rel="stylesheet" href="%style_url%" type="text/css" media="screen" />
  <script type="text/javascript">
  // <![CDATA[

  function popupCode( url ) {
    window.open(url, "Code", "resizable=yes,scrollbars=yes,toolbar=no,status=no,height=150,width=400")
  }

  function toggleCode( id ) {
    if ( document.getElementById )
      elem = document.getElementById( id );
    else if ( document.all )
      elem = eval( "document.all." + id );
    else
      return false;

    elemStyle = elem.style;

    if ( elemStyle.display != "block" ) {
      elemStyle.display = "block"
    } else {
      elemStyle.display = "none"
    }

    return true;
  }

  // Make codeblocks hidden by default
  document.writeln( "<style type=\\"text/css\\">div.method-source-code { display: none }</style>" )

  // ]]>
  </script>

</head>
<body>
}


#####################################################################
### C O N T E X T   C O N T E N T   T E M P L A T E
#####################################################################

CONTEXT_CONTENT = %{
}


#####################################################################
### F O O T E R   T E M P L A T E
#####################################################################
FOOTER = %{
<div id="validator-badges">
  <p><small><a href="http://validator.w3.org/check/referer">[Validate]</a></small></p>
</div>

</body>
</html>
}


#####################################################################
### F I L E   P A G E   H E A D E R   T E M P L A T E
#####################################################################

FILE_PAGE = %{
  <div id="fileHeader">
    <h1>%short_name%</h1>
    <table class="header-table">
    <tr class="top-aligned-row">
      <td><strong>Path:</strong></td>
      <td>%full_path%
IF:cvsurl
        &nbsp;(<a href="%cvsurl%"><acronym title="Concurrent Versioning System">CVS</acronym></a>)
ENDIF:cvsurl
      </td>
    </tr>
    <tr class="top-aligned-row">
      <td><strong>Last Update:</strong></td>
      <td>%dtm_modified%</td>
    </tr>
    </table>
  </div>
}


#####################################################################
### C L A S S   P A G E   H E A D E R   T E M P L A T E
#####################################################################

CLASS_PAGE = %{
    <div id="classHeader">
        <table class="header-table">
        <tr class="top-aligned-row">
          <td><strong>%classmod%</strong></td>
          <td class="class-name-in-header">%full_name%</td>
        </tr>
        <tr class="top-aligned-row">
            <td><strong>In:</strong></td>
            <td>
START:infiles
IF:full_path_url
                <a href="%full_path_url%">
ENDIF:full_path_url
                %full_path%
IF:full_path_url
                </a>
ENDIF:full_path_url
IF:cvsurl
        &nbsp;(<a href="%cvsurl%"><acronym title="Concurrent Versioning System">CVS</acronym></a>)
ENDIF:cvsurl
        <br />
END:infiles
            </td>
        </tr>

IF:parent
        <tr class="top-aligned-row">
            <td><strong>Parent:</strong></td>
            <td>
IF:par_url
                <a href="%par_url%">
ENDIF:par_url
                %parent%
IF:par_url
               </a>
ENDIF:par_url
            </td>
        </tr>
ENDIF:parent
        </table>
    </div>
}

NODE_PAGE = %{
    <div id="nodeHeader">
        <table class="header-table">
        <tr class="top-aligned-row">
          <td><strong>%classmod%</strong></td>
          <td class="class-name-in-header">%full_name%</td>
        </tr>
        <tr class="top-aligned-row">
            <td><strong>In:</strong></td>
            <td>
START:infiles
IF:full_path_url
                <a href="%full_path_url%">
ENDIF:full_path_url
                %full_path%
IF:full_path_url
                </a>
ENDIF:full_path_url
IF:cvsurl
        &nbsp;(<a href="%cvsurl%"><acronym title="Concurrent Versioning System">CVS</acronym></a>)
ENDIF:cvsurl
        <br />
END:infiles
            </td>
        </tr>

IF:parent
        <tr class="top-aligned-row">
            <td><strong>Parent:</strong></td>
            <td>
IF:par_url
                <a href="%par_url%">
ENDIF:par_url
                %parent%
IF:par_url
               </a>
ENDIF:par_url
            </td>
        </tr>
ENDIF:parent
        </table>
    </div>
}

PLUGIN_PAGE = %{
    <div id="classHeader">
        <table class="header-table">
        <tr class="top-aligned-row">
          <td><strong>%classmod%</strong></td>
          <td class="class-name-in-header">%full_name%</td>
        </tr>
        <tr class="top-aligned-row">
            <td><strong>In:</strong></td>
            <td>
START:infiles
IF:full_path_url
                <a href="%full_path_url%">
ENDIF:full_path_url
                %full_path%
IF:full_path_url
                </a>
ENDIF:full_path_url
IF:cvsurl
        &nbsp;(<a href="%cvsurl%"><acronym title="Concurrent Versioning System">CVS</acronym></a>)
ENDIF:cvsurl
        <br />
END:infiles
            </td>
        </tr>
        </table>
    </div>
}


#####################################################################
### M E T H O D   L I S T   T E M P L A T E
#####################################################################

PLUGIN_LIST = %{

  <div id="contextContent">
IF:description
    <div id="description">
      %description%
    </div>
ENDIF:description


IF:toc
    <div id="contents-list">
      <h3 class="section-bar">Contents</h3>
      <ul>
START:toc
      <li><a href="#%href%">%secname%</a></li>
END:toc
     </ul>
ENDIF:toc
   </div>

  </div>

<!-- Confine -->
IF:confine
START:confine
  <div id="attribute-list">
    <h3 class="section-bar">Confine</h3>
    %type%&nbsp;%value%
    <div class="name-list">
    </div>
  </div>
END:confine
ENDIF:confine

<!-- Type -->
IF:type
  <div id="attribute-list">
    <h3 class="section-bar">Type</h3>
    %type%
    <div class="name-list">
    </div>
  </div>
ENDIF:type

START:sections
    <div id="section">
IF:sectitle
      <h2 class="section-title"><a name="%secsequence%">%sectitle%</a></h2>
IF:seccomment
      <div class="section-comment">
        %seccomment%
      </div>
ENDIF:seccomment
ENDIF:sectitle
END:sections
}


METHOD_LIST = %{

  <div id="contextContent">
IF:diagram
    <div id="diagram">
      %diagram%
    </div>
ENDIF:diagram

IF:description
    <div id="description">
      %description%
    </div>
ENDIF:description


IF:toc
    <div id="contents-list">
      <h3 class="section-bar">Contents</h3>
      <ul>
START:toc
      <li><a href="#%href%">%secname%</a></li>
END:toc
     </ul>
ENDIF:toc
   </div>

<!-- if childs -->
IF:childs
       <div id="childs">
         <h3 class="section-bar">Inherited by</h3>
         <div id="childs-list">
START:childs
           <span class="child-name">HREF:aref:name:</span>
END:childs
         </div>
       </div>
ENDIF:childs

IF:methods
    <div id="method-list">
      <h3 class="section-bar">Defines</h3>

      <div class="name-list">
START:methods
      HREF:aref:name:&nbsp;&nbsp;
END:methods
      </div>
    </div>
ENDIF:methods

IF:resources
    <div id="method-list">
      <h3 class="section-bar">Resources</h3>

      <div class="name-list">
START:resources
      HREF:aref:name:&nbsp;&nbsp;
END:resources
      </div>
    </div>
ENDIF:resources

  </div>


    <!-- if includes -->
IF:includes
    <div id="includes">
      <h3 class="section-bar">Included Classes</h3>

      <div id="includes-list">
START:includes
        <span class="include-name">HREF:aref:name:</span>
END:includes
      </div>
    </div>
ENDIF:includes

    <!-- if requires -->
IF:requires
    <div id="requires">
      <h3 class="section-bar">Required Classes</h3>

      <div id="requires-list">
START:requires
        <span class="require-name">HREF:aref:name:</span>
END:requires
      </div>
    </div>
ENDIF:requires

    <!-- if realizes -->
IF:realizes
    <div id="realizes">
      <h3 class="section-bar">Realized Resources</h3>

      <div id="realizes-list">
START:realizes
        <span class="realizes-name">HREF:aref:name:</span>
END:realizes
      </div>
    </div>
ENDIF:realizes

START:sections
    <div id="section">
IF:sectitle
      <h2 class="section-title"><a name="%secsequence%">%sectitle%</a></h2>
IF:seccomment
      <div class="section-comment">
        %seccomment%
      </div>
ENDIF:seccomment
ENDIF:sectitle

<!-- if facts -->
IF:facts
    <div id="class-list">
      <h3 class="section-bar">Custom Facts</h3>
START:facts
            HREF:aref:name:&nbsp;&nbsp;
END:facts
    </div>
ENDIF:facts

<!-- if plugins -->
IF:plugins
    <div id="class-list">
      <h3 class="section-bar">Plugins</h3>
START:plugins
HREF:aref:name:&nbsp;&nbsp;
END:plugins
    </div>
ENDIF:plugins

<!-- if nodes -->
IF:nodelist
    <div id="class-list">
      <h3 class="section-bar">Nodes</h3>

      %nodelist%
    </div>
ENDIF:nodelist

<!-- if class -->
IF:classlist
    <div id="class-list">
      <h3 class="section-bar">Classes and Modules</h3>

      %classlist%
    </div>
ENDIF:classlist

IF:constants
    <div id="constants-list">
      <h3 class="section-bar">Global Variables</h3>

      <div class="name-list">
        <table summary="Variables">
START:constants
        <tr class="top-aligned-row context-row">
          <td class="context-item-name">%name%</td>
          <td>=</td>
          <td class="context-item-value">%value%</td>
IF:desc
          <td width="3em">&nbsp;</td>
          <td class="context-item-desc">%desc%</td>
ENDIF:desc
        </tr>
END:constants
        </table>
      </div>
    </div>
ENDIF:constants

IF:aliases
    <div id="aliases-list">
      <h3 class="section-bar">External Aliases</h3>

      <div class="name-list">
                        <table summary="aliases">
START:aliases
        <tr class="top-aligned-row context-row">
          <td class="context-item-name">%old_name%</td>
          <td>-&gt;</td>
          <td class="context-item-value">%new_name%</td>
        </tr>
IF:desc
      <tr class="top-aligned-row context-row">
        <td>&nbsp;</td>
        <td colspan="2" class="context-item-desc">%desc%</td>
      </tr>
ENDIF:desc
END:aliases
                        </table>
      </div>
    </div>
ENDIF:aliases


IF:attributes
    <div id="attribute-list">
      <h3 class="section-bar">Attributes</h3>

      <div class="name-list">
        <table>
START:attributes
        <tr class="top-aligned-row context-row">
          <td class="context-item-name">%name%</td>
IF:rw
          <td class="context-item-value">&nbsp;[%rw%]&nbsp;</td>
ENDIF:rw
IFNOT:rw
          <td class="context-item-value">&nbsp;&nbsp;</td>
ENDIF:rw
          <td class="context-item-desc">%a_desc%</td>
        </tr>
END:attributes
        </table>
      </div>
    </div>
ENDIF:attributes



    <!-- if method_list -->
IF:method_list
    <div id="methods">
START:method_list
IF:methods
      <h3 class="section-bar">Defines</h3>

START:methods
      <div id="method-%aref%" class="method-detail">
        <a name="%aref%"></a>

        <div class="method-heading">
IF:codeurl
          <a href="%codeurl%" target="Code" class="method-signature"
            onclick="popupCode('%codeurl%');return false;">
ENDIF:codeurl
IF:sourcecode
          <a href="#%aref%" class="method-signature">
ENDIF:sourcecode
IF:callseq
          <span class="method-name">%callseq%</span>
ENDIF:callseq
IFNOT:callseq
          <span class="method-name">%name%</span><span class="method-args">%params%</span>
ENDIF:callseq
IF:codeurl
          </a>
ENDIF:codeurl
IF:sourcecode
          </a>
ENDIF:sourcecode
        </div>

        <div class="method-description">
IF:m_desc
          %m_desc%
ENDIF:m_desc
IF:sourcecode
          <p><a class="source-toggle" href="#"
            onclick="toggleCode('%aref%-source');return false;">[Source]</a></p>
          <div class="method-source-code" id="%aref%-source">
<pre>
%sourcecode%
</pre>
          </div>
ENDIF:sourcecode
        </div>
      </div>

END:methods
ENDIF:methods
END:method_list

    </div>
ENDIF:method_list


    <!-- if resource_list -->
IF:resource_list
    <div id="resources">
    <h3 class="section-bar">Resources</h3>
START:resource_list

      <div id="method-%aref%" class="method-detail">
        <a name="%aref%"></a>

        <div class="method-heading">
          <span class="method-name">%name%</span><br />
IF:params
START:params
          &nbsp;&nbsp;&nbsp;<span class="method-args">%name% => %value%</span><br />
END:params
ENDIF:params
        </div>

        <div class="method-description">
IF:m_desc
          %m_desc%
ENDIF:m_desc
        </div>
      </div>
END:resource_list

    </div>
ENDIF:resource_list

END:sections
}


#####################################################################
### B O D Y   T E M P L A T E
#####################################################################

BODY = HEADER + %{

!INCLUDE!  <!-- banner header -->

  <div id="bodyContent">

} +  METHOD_LIST + %{

  </div>

} + FOOTER

BODYINC = HEADER + %{

!INCLUDE!  <!-- banner header -->

  <div id="bodyContent">

!INCLUDE!

  </div>

} + FOOTER



#####################################################################
### S O U R C E   C O D E   T E M P L A T E
#####################################################################

SRC_PAGE = XHTML_PREAMBLE + %{
<html>
<head>
  <title>%title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
  <link rel="stylesheet" href="%style_url%" type="text/css" media="screen" />
</head>
<body class="standalone-code">
  <pre>%code%</pre>
</body>
</html>
}


#####################################################################
### I N D E X   F I L E   T E M P L A T E S
#####################################################################

FR_INDEX_BODY = %{
!INCLUDE!
}

FILE_INDEX = XHTML_PREAMBLE + %{
<!--

    %list_title%

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>%list_title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
  <link rel="stylesheet" href="%style_url%" type="text/css" />
  <base target="docwin" />
</head>
<body>
<div id="index">
  <h1 class="section-bar">%list_title%</h1>
  <div id="index-entries">
START:entries
    <a href="%href%">%name%</a><br />
END:entries
  </div>
</div>
</body>
</html>
}

TOP_INDEX = XHTML_PREAMBLE + %{
<!--

    %list_title%

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>%list_title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
  <link rel="stylesheet" href="%style_url%" type="text/css" />
  <base target="classes" />
  <SCRIPT LANGUAGE="JavaScript">
  <!--
  function load(classlist,module) {
      parent.classes.location.href = classlist;
      parent.docwin.location.href = module;
  }
  //--></SCRIPT>
</head>
<body>
<div id="index">
  <h1 class="section-bar">%list_title%</h1>
  <div id="index-entries">
START:entries
    <a href="%classlist%" onclick="load('%classlist%','%module%'); return true;">%name%</a><br />
END:entries
  </div>
</div>
</body>
</html>
}


CLASS_INDEX = FILE_INDEX
METHOD_INDEX = FILE_INDEX

COMBO_INDEX = XHTML_PREAMBLE + %{
<!--

    %classes_title% &amp; %defines_title%

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>%classes_title% &amp; %defines_title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
  <link rel="stylesheet" href="../%style_url%" type="text/css" />
  <base target="docwin" />
  <SCRIPT LANGUAGE="JavaScript">
  <!--
  function load(url) {
      parent.docwin.location.href = url;
  }
  //--></SCRIPT>

</head>
<body>
<div id="index">

    <a href="../fr_class_index.html" target="classes">All Classes</a><br />


<h1 class="section-bar">Module</h1>
  <div id="index-entries">
START:module
    <a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:module
  </div>
  </div>
<div id="index">

IF:nodes
  <h1 class="section-bar">%nodes_title%</h1>
  <div id="index-entries">
START:nodes
<a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:nodes
  </div>
ENDIF:nodes

IF:classes
  <h1 class="section-bar">%classes_title%</h1>
  <div id="index-entries">
START:classes
<a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:classes
  </div>
ENDIF:classes

IF:defines
  <h1 class="section-bar">%defines_title%</h1>
    <div id="index-entries">
START:defines
<a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:defines
    </div>
ENDIF:defines

IF:facts
  <h1 class="section-bar">%facts_title%</h1>
    <div id="index-entries">
START:facts
<a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:facts
    </div>
ENDIF:facts


IF:plugins
  <h1 class="section-bar">%plugins_title%</h1>
    <div id="index-entries">
START:plugins
<a href="%href%" onclick="load('%href%'); return true;">%name%</a><br />
END:plugins
    </div>
ENDIF:plugins

</div>
</body>
</html>
}

INDEX = %{<?xml version="1.0" encoding="%charset%"?>
<!DOCTYPE html
     PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">

<!--

    %title%

  -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <title>%title%</title>
  <meta http-equiv="Content-Type" content="text/html; charset=%charset%" />
</head>
<frameset cols="20%, 80%">
    <frameset rows="30%,70%">
        <frame src="fr_modules_index.html"  title="All Modules" />
        <frame src="fr_class_index.html" name="classes" title="Classes & Defines" />
    </frameset>
    <frame src="%initial_page%" name="docwin" />
</frameset>
</html>
}



  end # module Page
end # class RDoc

require 'rdoc/generators/template/html/one_page_html'
