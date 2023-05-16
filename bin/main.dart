import "dart:io";
import "dart:math" as math;

import "package:parser_combinator/parser_combinator.dart";

import "decision.dart";
import "node.dart";
import "parse.dart";

typedef Table = (List<Row> rows, Set<int> marks);
typedef Row = Map<Proposition, bool>;

enum Color { red, blue, green }

void main(List<String> args) {
  stdout.writeln("""
    Commands:
      `truth <proposition>`
        - Generates a truth table for the specified proposition.

      `arg <proposition[0]>; <proposition[1]>; ... <proposition[N-1]> => <proposition>`
        - Shows the validity of the argument.
    """
      .unindent());
  stdout.write("> ");

  String input = stdin.readLineSync() ?? (throw Exception("Unable to read stdin."));

  switch (commandParser.peg(input)) {
    case Success(value: (Command.truthTable, String textProposition)):
      switch (propositionParser.peg(textProposition)) {
        case Success<Proposition>(value: Proposition proposition):
          Iterable<VariableProposition> variables = proposition.variables();
          Table table = generatePlainTable(proposition);

          String renderedTable = renderTable(table);
          Decision decision = generateDecision(proposition, table);

          stdout.writeln("Your proposition is: $proposition");
          stdout.writeln("The variables are: $variables");
          stdout.writeln(renderedTable);
          stdout.writeln("The proposition is: $decision");

          break;
        case Failure(:String failureMessage):
          stdout.writeln(failureMessage);

          break;
        case Empty():
          break;
      }
      break;
    case Success(value: (Command.argument, String args)):
      switch (argumentParser.peg(args)) {
        case Success(value: (List<Proposition> premises, Proposition conclusion)):
          LabeledProposition left = premises //
              .reduce((Proposition a, Proposition b) => a & b)
              .labeled("ℙ");
          LabeledProposition right = conclusion.labeled("ℂ");

          var (Table table && (List<Row> rows, Set<int> marks)) = generateMarkedTable(left, right);
          String renderedTable = renderTable(table);

          stdout.writeln("Your proposition is: $left => $right");
          stdout.writeln(renderedTable);

          Iterable<Row> criticalRows = marks //
              .map((int y) => rows[y])
              .where((Row r) => r[left] ?? false);

          Set<bool> results = criticalRows //
              .map((Row r) => r[right] ?? false)
              .toSet();

          if (results.contains(false)) {
            stdout.writeln("Due to the fact that there is a "
                "false conclusion in the critical rows, "
                "argument is not logically valid.");
          } else {
            stdout.writeln("Since there are no false conclusions, "
                "the argument is logically valid.");
          }

          break;
        case Failure(:String failureMessage):
          stdout.writeln("Failure in parsing.");
          stdout.writeln(failureMessage);

          break;
        case Empty():
          break;
      }
    case Failure(:String failureMessage):
      stdout.writeln(failureMessage);

      break;
    case Empty():
      break;
  }
}

extension on String {
  bool get isOnlyDashes {
    for (String c in split("")) {
      if (c != "-") {
        return false;
      }
    }
    return true;
  }

  String padCenter(int count, [String padding = " "]) {
    int remaining = count - length;
    int left = length + remaining ~/ 2;

    return padLeft(left, padding).padRight(count, padding);
  }

  String unindent() {
    /// Removing the unnecessary right trailing line breaks
    List<String> lines = this.replaceAll("\r", "").trimRight().split("\n");

    List<int> existingIndentations = lines

        /// To calculate the indentation, just get the length of the whole line
        ///   subtracted by the length of the whole line with its left space trimmed.
        ///
        /// line := `  hello`
        /// line_$trimmed := `hello`
        ///
        /// len(line) = 7
        /// len(line_$trimmed) = 5
        /// therefore indentation := 2
        .map((String l) => l.length - l.trimLeft().length)

        /// Since we're looking for the minimal indentation,
        ///   we must not include zero because min(a, 0) := 0.
        .where((int l) => l > 0)
        .toList();

    /// If there are no indentations, then the string is empty / consists of purely newlines.
    if (existingIndentations.isEmpty) {
      return this;
    }

    /// Since at this point, [existingIndentations] should not be empty,
    ///   we can call [reduce] without throwing.
    int commonIndentationLength = existingIndentations.reduce(math.min);
    String unindented = lines //
        /// If the line is empty, then just ignore it because the index, assuming
        ///   [commonIndentationLength] > 0, will go out of bounds.
        .map((String l) => l.isEmpty ? l : l.substring(commonIndentationLength))
        .join("\n");

    return unindented;
  }
}

String readLine() => stdin.readLineSync() ?? (throw Exception("Unable to read stdin."));

/// Yields all the possible combinations of 0 and 1
///   of all the [variables].
///
/// Should result in 2^n [Environment] objects where
///   n is the amount of variables.
Iterable<Environment> generateEnvironments(List<VariableProposition> variables) sync* {
  if (variables.isEmpty) {
    yield <Proposition, bool>{};
    return;
  }

  var [VariableProposition first, ...List<VariableProposition> rest] = variables;
  for (Environment remaining in generateEnvironments(rest)) {
    yield <Proposition, bool>{first: true, ...remaining};
    yield <Proposition, bool>{first: false, ...remaining};
  }
}

Row generateRow(Proposition root, Environment environment) {
  Iterable<MapEntry<Proposition, bool>> definitions = root //
      .traverse()
      .map((Proposition p) => MapEntry<Proposition, bool>(p, p.evaluate(environment)));

  return Row.fromEntries(definitions);
}

Table generatePlainTable(Proposition root) {
  List<VariableProposition> variables = root.variables().toList();
  List<Row> rows = generateEnvironments(variables).map((Environment e) => generateRow(root, e)).toList();

  return (rows, <int>{});
}

Table generateMarkedTable(LabeledProposition premise, LabeledProposition conclusion) {
  List<VariableProposition> variables = premise.variables().union(conclusion.variables()).toList();

  List<Row> rows = generateEnvironments(variables) //
      .map((Environment env) => <Proposition, bool>{...generateRow(premise, env), ...generateRow(conclusion, env)})
      .toList();
  Set<int> marks = List<int>.generate(rows.length, (int i) => i) //
      .where((int y) => rows[y][premise] ?? false)
      .toSet();

  return (rows, marks);
}

String renderTable(Table table) {
  /// Takes the keys that are common between all the rows,
  ///   and sorts it by their comparison.
  var (List<Row> rows, Set<int> marks) = table;
  List<Proposition> keys = rows //
      .map((Row row) => row.keys.toSet())
      .reduce((Set<Proposition> a, Set<Proposition> b) => a.intersection(b))
      .toList()
    ..sort((Proposition a, Proposition b) => a.weight - b.weight);

  /// The table width.
  int width = keys.length;

  /// This is the basic string matrix that will be used in
  ///   determining the maximum length of each column.
  List<List<String>> matrix = <List<String>>[
    <String>[for (Proposition repr in keys) repr.repr()],
    for (Row row in rows)
      <String>[
        for (Proposition key in keys)
          if (row[key] ?? false) "1" else "0"
      ]
  ];

  /// This contains all the maximum widths in each column.
  List<int> profile = <int>[
    for (int x = 0; x < width; ++x) //
      matrix //
          .map((List<String> r) => r[x].length)
          .reduce((int a, int b) => a > b ? a : b),
  ];

  /// This is the final matrix that will be used in
  ///   rendering the table.
  List<List<String>> paddedMatrix = <List<String>>[
    <String>[for (int x = 0; x < width; ++x) matrix[0][x].padCenter(profile[x])],
    <String>[for (int x = 0; x < width; ++x) "-" * profile[x]],
    for (int y = 1; y < matrix.length; ++y) //
      <String>[for (int x = 0; x < width; ++x) matrix[y][x].padCenter(profile[x])]
  ];

  StringBuffer buffer = StringBuffer();
  for (int y = 0; y < paddedMatrix.length; ++y) {
    List<String> row = paddedMatrix[y];

    if (marks.isNotEmpty) {
      if (marks.contains(y - 2)) {
        buffer.write("* ");
      } else {
        buffer.write("  ");
      }
    }
    for (int x = 0; x < width; ++x) {
      buffer.write(row[x]);

      if (x < width - 1) {
        if (row[x].isOnlyDashes) {
          buffer.write("-+-");
        } else {
          buffer.write(" | ");
        }
      }
    }
    buffer.writeln();
  }

  return buffer.toString();
}
