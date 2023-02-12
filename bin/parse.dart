// ignore_for_file: avoid_single_cascade_in_expression_statements

import "package:parser_combinator/parser_combinator.dart" as parser;
import "package:parser_combinator/parser_combinator.dart" show Parser, ExpressionBuilder;

import "node.dart";

Parser<void> leadsOp = parser.trie(["⇒", "=>", "leads to", "therefore"]).trim();
Parser<void> iffOp = parser.trie(["<->", "=", "↔", "iff", "eq", "xnor"]).trim();
Parser<void> ifOp = parser.trie(["->", "→", "then"]).trim();
Parser<void> orOp = parser.trie(["|", "∨", "or"]).trim();
Parser<void> xorOp = parser.trie(["^", "⊻", "⊕", "xor"]).trim();
Parser<void> andOp = parser.trie(["&", "∧", "and", ","]).trim();
Parser<void> notOp = parser.trie(["!", "¬", "not"]).trim();

Parser<Proposition> propositionParser() {
  ExpressionBuilder<Proposition> builder = ExpressionBuilder()
    ..group //
        .atomic(parser.identifier(), (name) => VariableProposition.new(name))
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
    ..group //
        .right(leadsOp, (left, _, right) => Proposition.argument(left, right));

  return builder.build();
}
