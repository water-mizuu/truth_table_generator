import "package:parser_combinator/classes.dart";
import "package:parser_combinator/parser_combinator.dart" as parser;

import "node.dart";

enum Command { truthTable, argument }

typedef Argument = (Command, String);

Parser<Argument> commandParser() {
  Parser<String> rest = (parser.newline().not() + parser.any()).plus().flat().trim();
  Parser<Argument> truthTable = rest.prefix(parser.string("truth")).map((String $) => (Command.truthTable, $));
  Parser<Argument> argument = rest.prefix(parser.string("arg")).map((String $) => (Command.argument, $));

  return truthTable / argument;
}

Parser<(List<Proposition>, Proposition)> argumentParser() {
  Parser<String> leadsOp = parser.trie(<String>["⇒", "=>", "leads to", "therefore"]).trim();
  Parser<Proposition> proposition = propositionParser();

  Parser<List<Proposition>> premise = proposition.separated(parser.trie(<String>[",", ";"]).trim());
  Parser<Proposition> conclusion = proposition;

  return (premise + leadsOp + conclusion).map((List<Object> $) {
    var [List<Proposition> premises as List<Proposition>, _, Proposition conclusion as Proposition] = $;

    return (premises, conclusion);
  });
}

/// Parses propositions with the formal grammar:
///
/// ```
/// argument = if-only-if "⇒" argument
///          | if-only-if "=>" argument
///          | if-only-if "leads to" argument
///          | if-only-if "therefore" argument
///          | if-only-if
///
/// if-only-if = conditional !"=>" "=" if-only-if
///            | conditional "<->" if-only-if
///            | conditional "↔" if-only-if
///            | conditional "iff" if-only-if
///            | conditional "eq" if-only-if
///            | conditional "xnor" if-only-if
///            | conditional
///
/// conditional = or-xor "->" conditional
///             | or-xor "→" conditional
///             | or-xor "then" conditional
///             | or-xor
///
/// or-xor = or-xor "|" and
///        | or-xor "∨" and
///        | or-xor "or" and
///        | or-xor "^" and
///        | or-xor "⊻" and
///        | or-xor "⊕" and
///        | or-xor "xor" and
///        | and
///
/// and = and "&" not
///     | and "∧" not
///     | and "and" not
///     | and "," not
///     | not
///
/// not = "!" not
///     | "¬" not
///     | "not" not
///     | base
///
/// base = "(" argument ")"
///      | identifier
/// ```

// Parser<Proposition> propositionParser() => _argumentParser.$();

// Parser<Proposition> _argument() => parser.choice([
//       (_ifAndOnlyIf.$(), _leadsOp, _argument.$()).sequence().map(($) {
//         var (Proposition left, _, Proposition right) = $;

//         return Proposition.argument(left, right);
//       }),
//       _ifAndOnlyIf.$(),
//     ]);
// Parser<Proposition> _ifAndOnlyIf() => parser.choice([
//   parser.sequence
// ]);
// Parser<Proposition> _conditional() => parser.choice([]);
// Parser<Proposition> _orXor() => parser.choice([]);
// Parser<Proposition> _and() => parser.choice([]);
// Parser<Proposition> _not() => parser.choice([]);
// Parser<Proposition> _base() => parser.choice([]);

// Parser<void> _leadsOp = parser.trie(["⇒", "=>", "leads to", "therefore"]).trim();
// Parser<void> _iffOp = parser.trie(["<->", "=", "↔", "iff", "eq", "xnor"]).prefix(parser.string("=>").not()).trim();
// Parser<void> _ifOp = parser.trie(["->", "→", "then"]).trim();
// Parser<void> _orOp = parser.trie(["|", "∨", "or"]).trim();
// Parser<void> _xorOp = parser.trie(["^", "⊻", "⊕", "xor"]).trim();
// Parser<void> _andOp = parser.trie(["&", "∧", "and", ","]).trim();
// Parser<void> _notOp = parser.trie(["!", "¬", "not"]).trim();

Parser<Proposition> propositionParser() {
  Parser<void> iffOp = <String>["<->", "=", "↔", "iff", "eq", "xnor"].trie().prefix.not(parser.string("=>")).trim();
  Parser<void> ifOp = <String>["->", "→", "then"].trie().trim();
  Parser<void> orOp = <String>["|", "∨", "or"].trie().trim();
  Parser<void> xorOp = <String>["^", "⊻", "⊕", "xor"].trie().trim();
  Parser<void> andOp = <String>["&", "∧", "and", ","].trie().trim();
  Parser<void> notOp = <String>["!", "¬", "not"].trie().trim();

  ExpressionBuilder<Proposition> builder = ExpressionBuilder<Proposition>()
        ..group //
            .atomic(parser.identifier(), (String name) => Proposition.variable(name))
            .surround("(".p().trim(), ")".p().trim(), (_, Proposition value, __) => value)
        ..group //
            .pre(notOp, (_, Proposition value) => Proposition.not(value))
        ..group //
            .left(andOp, (Proposition left, _, Proposition right) => Proposition.and(left, right))
        ..group //
            .left(orOp, (Proposition left, _, Proposition right) => Proposition.or(left, right))
            .left(xorOp, (Proposition left, _, Proposition right) => Proposition.xor(left, right))
        ..group //
            .right(ifOp, (Proposition left, _, Proposition right) => Proposition.conditional(left, right))
        ..group //
            .right(iffOp, (Proposition left, _, Proposition right) => Proposition.iff(left, right))
      //
      ;
  return builder.build();
}
