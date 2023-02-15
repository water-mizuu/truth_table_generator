// ignore_for_file: avoid_single_cascade_in_expression_statements

import "package:parser_combinator/classes.dart";
import "package:parser_combinator/parser_combinator.dart" as parser;

import "node.dart";

enum Command { truthTable, argument }
typedef Argument = (Command, String);

Parser<Argument> commandParser() {
  Parser<String> rest = (parser.newline().not() + parser.any()).plus().flat().trim();
  Parser<Argument> truthTable = (parser.string("truth") + rest).map(($) => (Command.truthTable, $[1] as String));
  Parser<Argument> argument = (parser.string("arg") + rest).map(($) => (Command.argument, $[1] as String));

  return truthTable / argument;      
}

Parser<(List<Proposition>, Proposition)> argumentParser() {
  Parser<Proposition> proposition = propositionParser();

  Parser<List<Proposition>> premise = proposition.separated(parser.string(";").trim());
  Parser<Proposition> conclusion = proposition;

  return (premise + parser.string("=>").trim() + conclusion).map(($) {
    var [premises as List<Proposition>, _, conclusion as Proposition] = $;

    return (premises, conclusion);
  });
}

Parser<Proposition> propositionParser() {
  // Parser<void> leadsOp = parser.trie(["⇒", "=>", "leads to", "therefore"]).trim();
  Parser<void> iffOp = parser.trie(["<->", "=", "↔", "iff", "eq", "xnor"]).prefix(parser.string("=>").not()).trim();
  Parser<void> ifOp = parser.trie(["->", "→", "then"]).trim();
  Parser<void> orOp = parser.trie(["|", "∨", "or"]).trim();
  Parser<void> xorOp = parser.trie(["^", "⊻", "⊕", "xor"]).trim();
  Parser<void> andOp = parser.trie(["&", "∧", "and", ","]).trim();
  Parser<void> notOp = parser.trie(["!", "¬", "not"]).trim();

  ExpressionBuilder<Proposition> builder = ExpressionBuilder()
    ..group //
        .atomic(parser.identifier(), (name) => VariableProposition(name))
        .surround("(".p().trim(), ")".p().trim(), (_, value, __) => value)
    ..group //
        .pre(notOp, (_, value) => Proposition.not(value))
    ..group //
        .left(andOp, (left, _, right) => Proposition.and(left, right))
    ..group //
        .left(orOp, (left, _, right) => Proposition.or(left, right))
        .left(xorOp, (left, _, right) => Proposition.xor(left, right))
    ..group //
        .right(ifOp, (left, _, right) => Proposition.conditional(left, right))
    ..group //
        .right(iffOp, (left, _, right) => Proposition.iff(left, right))
    // ..group //
    //     .right(leadsOp, (left, _, right) => Proposition.argument(left, right));
    ;
  return builder.build();
}
