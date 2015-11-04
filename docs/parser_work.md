Working on Parser Logic
===

This document contains advice related to doing grammar / parser work.

From Grammar to Ruby
---
The grammar is described in a `.ra` (racc) file. For the "future parser", this is in
lib/puppet/pops/parser/egrammar.ra and it is combined with the parser_support.rb file in the
same directory and processed by race. The output is the resulting parser (in eparser.rb).

Never modify the `parser.rb` by hand.

Merge conflicts
---
Simply touch the `egrammar.ra` (unless it was changed by resolving merge conflicts), and
then rebuild the parser by running make in the same directory.

The resulting `eparser.rb` should be checked in.

The eparser.rb and Racc runtime
---
If you look inside the `eparser.rb` file, you see several tables and a set of methods.
The tables are used by the racc runtime (written n C and part of Ruby), and it calls back to
the methods that implement the actions that were expressed in the grammar.

Note that the file contains source file/line references to the grammar file, thus ensuring
that runtime exceptions appear to come from the grammar file (as they should).

Grammar Ambiguities
---
If you are working with grammar changes, you may run into ambiguity problems. There are two kinds of conflicts:

* shift/reduce
* reduce/reduce

Bot of these conflicts mean that racc can not determine what to do when the sequence of source tokens have made it reach a particular state.

A "shift" can be read as "tell me more", and "reduce" as "got it". So a shift/reduce is an ambiguity
where the grammar expresses that it is both ok to accept the state as complete, or to continue and build something more elaborate. A reduce/reduce, is trickier, since this means we reached a state
where there appears to be no difference between completing one of multiple choices.

There are several reasons to why shift/reduce, and reduce/reduce conflicts occur:

* The language is truly ambiguous, i.e. there is no way to differentiate between two or more
  choices. This is poorly design language feature and it can only be fixed completely by changing
  the language. It is however possible to make such a problem less of an issue by hardcoding
  a decision and thus blocking one interpretation of the input from occurring. When doing so, the
  trick is to make this happen in a very dark corner of the programming language; i.e. in
  a sequence that is of little practical use. In all cases, avoid having ambiguities in the
  language.

* Racc only performs one token look-ahead over rule boundaries, any lookahead beyond that must
  take place in one and the same rule!
  To resolve these, you can introduce additional states, you can roll up rules into a larger rule, or
  you can assign precedence to rules.
  * "flattening" the grammar means  that you spell out a sequence of tokens even if it would
    be less repetition to refer to a rule. Remember, breaking up sequences into rules is not
    just syntactic, it changes how the parser works.
  * adding states, means that you break up sequences into pieces that are unambiguous; thus making
    it possible for the grammar to reduce them. Unfortunately this makes the grammar quite abstract
    and hard to read.
  * Assigning precedence to rules can solve a shift/reduce. The decision with the highest precedence
    will win. When doing this for rules, great care must be taken as it may mean that certain rules
    can never be triggered.
  
* The language is an expression language and racc can not on its own determine the priority
  of operators - e.g. in 1 + 2 * 3, should the addition or the multiplication be performed first?
  Issues of this kind are easy to solve by giving operators a precedence.

As a rule of thumb, do not try to implement all semantics of the language in the grammar. It
is far better to make the grammar parse non sensical input and then validate the result than
trying to capture all semantics via grammar rules. This makes the grammar simpler and there
are far fewer grammar conflicts to deal with.

### How Racc signals Ambiguities

When the grammar (.ra file) is processed racc outputs information about unused/useless rules
and the number of shift/reduce, and reduce/reduce conflicts. It will still produce a parser, so
you must pay attention to this output. If you see conflicts it means that certain parts of
the grammar may be unreachable (racc has built in defaults that **may** be what you want, but
it is most often by accident).

When an ambiguity is reported. You need to generate a more detailed report. You do that by running
the makefile target `egrammar.output`. This produces a file with the same name. At the top of this
file, you will find a more detailed report of which states/rules that are involved in the ambiguity.

It may for instance say:

     state 168 contains one shift/reduce conflict
     
To find what this means, you search for "state 168", it is probably mentioned in several places
with a "goto state 168", search until you find the state itself. There you find a description
of that exact state; how it got there, and what racc considers at that point.

Here is a simple example:

    state 66

       7) syntactic_statements : syntactic_statements syntactic_statement _
       9) syntactic_statement : syntactic_statement _ COMMA expression

      COMMA         shift, and go to state 68
      $default      reduce using rule 7 (syntactic_statements)

The current state is shown with an `_`, thus we are looking at the state where the parser
has seen a `syntactic_statement`. We see below, that if it sees a COMMA, it will shift to
state 68 (to deal with the expression), and if not, it will reduce rule 7 (it will add one
syntactic_statement to the list of syntactic_statements).

If there is a conflict of a token/rule, it will be listed multiple times in the decision table.
Say if there was a conflict on the COMMA, it may be shown as:

      COMMA         shift, and go to state 68
      COMMA         reduce using rule 666 (the_trouble_rule)
      $default      reduce using rule 7 (syntactic_statements)


### How to find where the problem is

Each conflicting token/rule-pair is displayed in the output (as shown above), thus if the
same COMMA is involved in 3 conflicts, you will see 6 entries. The valuable piece of information is the name of the reduction rule in conflict. At this point, try to manually construct the sequence of input tokens that would lead up to the ambiguity. 
It may be that the problem in the grammar is "before" reaching the ambiguity
on the COMMA. Once you understand the sequence, you need to apply reasoning to find the resolution
of the problem.

If that proves to be hard, and your grammar produces a viable parser, you can build a
debugging parser, and turn on debugging output in the runtime. This gives you a trace of
what the parser decides when it parses the input. This is sometimes easier than manually
following the state changes using only the .output file. Often, you need both, because the trace
only tells you which of the alternatives that it took, not what the alternatives were.

And yes, this is extremely tedious and time consuming. You will most certainly want to run this
on as little source input as possible to avoid having your head explode.

### Generating a Debugging Parser

To generate a debugging parser, run the make target `egrammar.debug`. This creates an
eparser.rb (it overwrites the non-debugging variant). (**Do not check in this parser**, it is
much slower than the non debugging variant).

### Turning on Debug output

To turn on debug output, you need to set an instance variable. You do this in `parser_support.rb`
in the `_parse()` method. Simply change the line that by default reads:

    @yydebug = false
    
to

    @yydebug = true
    
Again, **Do not check in this change**.

Note that the @yydebug=true does nothing unless the parser is build for debugging - i.e. you
do not have to change it while you are switching from regular to non debugging version.

### Running with debugging on

When you run with debugging turned on, the trace will be printed to stdout, and each
decision; reading a token, shifting to another rule/state, and reduction of rules
is printed out.

Armed with that output and the .output file, you can now manually step through the grammar.

### Limiting the scope

Sometimes it is just impossible to figure out what is going wrong in a complex grammar.
You can try reducing the grammar by simply commenting out large sections of the grammar. Repeat this
for as long as the problem occurs. When you removed the problem, revert that change, then continue elsewhere until you have the smallest possible reproducer

Fixing Problems
---

### Precedence

Precedence is expressed in a table at the beginning of the grammar. It lists the precedence
from high (at the top) to low (at the bottom), and for each token (real or pseudo token)
the associativity (`left`, `right` `nonasoc`) is expressed before a token (or list of tokens).

e.g.

    prechigh
      left  HIGH
      nonassoc UMINUS
      left  TIMES DIV MODULO
      left  MINUS PLUS
      right EQUALS
      left  LOW
    preclow

The associativity tells racc how to group input with the same precedence; i.e. should 1 + 2 + 3 be treated as (1 + 2) + 3, or 1 + (2 + 3). A nonassoc means that racc does not allow this multiple
times in a row, e.g. an unary minus can not occur in a sequence and --1 is an error.

The example above shows two pseudo tokens HIGH and LOW that can be used in the grammar to
make a rule have a certain precedence. 

We can now express an otherwise ambiguous grammar like this:

    expr
      : expr PLUS  expr
      | expr MINUS expr
      | expr TIMES expr
      | expr DIV   expr
      |      MINUS expr =UMINUS
      
### "Decent Precedence"

Optionally, we can deal with precedence by grouping the expressions having the same precedence

    expr
      : mulexp             # to higher precedence
      | expr PLUS mulexp
      | expr MINUS mulexp
      
    mulexp
      : primary            # to higher precedence
      | mulexp TIMES primary
      | mulexp DIV primary

    primary
      : NUMBER
      
This has the same effect as setting the precedence and associativity in the precedence
table. 

I named this "Decent Precedence" since this mimics the behavior of a "recursive decent parser",
the type of parser that is usually written by hand.

### Assigning the precedence

The precedence of a rule can be assigned like this:

    |  MINUS expression  =UMINUS

This means that the lexer delivers a MINUS token, and when that is followed by an
expression, the result is an UMINUS operation. If we did not assign =UMINUS, the rule
would be given the precedence of MINUS.

Other options for fixing problems
---
    
### Creating look ahead / look behind in the lexer

Sometimes it is possible to solve an issue by doing a bit more work in the lexer. As an example,
the puppet grammar has LBRACK and LISTSTART tokens that are issued for the input '['. The lexer
can differentiate between the tokens - a LISTSTART occurs if at the beginning of the input, or after whitespace. This helps making input such as $a[1] and $a [1] non ambiguous before fed to the grammar
(where it is impossible to differentiate between them due to whitespace tokens not being part of
the information sent to the parser). (This is actually an example of "look behind").

Beware that any lookahead in the lexer is very expensive since it visits each and every
character in the source file. Look-behinds are cheap in comparison.
  
  
Literature
===

There is almost no documentation for racc. Luckily, it is a Ruby port of Yacc, and almost everything that is described for Yacc also applies to Racc (with the major exception that Racc uses rules
written in Ruby, and that the runtime methods are slightly different).

The best book on the topic is "O'Reilly Yacc & Lex". If you want to learn more about parsers, see "Compilers, Principles, Techniques and Tools" (Aho et.al), also known as 'the dragon book').


