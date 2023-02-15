import "dart:io";

import "package:parser_combinator/parser_combinator.dart";

import "node.dart";
import "parse.dart";

typedef Table = List<Row>;
typedef Row = Map<Proposition, bool>;

extension on String {
  bool get isOnlyDashes {
    List<String> chars = split("");
    Set<String> unique = chars.toSet();
    String joined = unique.join();

    return joined == "-";
  }

  String padCenter(int count, [String padding = " "]) {
    int remaining = count - length;
    int left = length + remaining ~/ 2;

    return padLeft(left, padding).padRight(count, padding);
  }

  String unindent() {
    RegExp emptySpace = RegExp(r"^\s+");

    List<String> lines = this.replaceAll("\r", "").trimRight().split("\n");
    List<int> indentations = lines
        .where((l) => l.isNotEmpty)
        .map((l) => emptySpace.matchAsPrefix(l)?.end ?? 0)
        .toList();
    
    print(indentations);
    if (indentations.isEmpty) {
      return this;
    }

    int unindent = indentations.reduce((a, b) => a < b ? a : b);
    String unindented = lines
        .map((l) => l.isEmpty ? l : l.substring(unindent))
        .join("\n");
    
    return unindented;
  }
}

String readLine() {
  return stdin.readLineSync() ?? (throw Exception("Unable to read stdin."));
}

void main(List<String> args) {
  stdout.writeln("""
    Commands:
      `truth <proposition>`
        - Generates a truth table for the specified proposition.
      
      `arg <proposition1>; <proposition2>; ... <propositionN> => <proposition>`
        - Shows the validity of the argument.
    """.unindent());
  stdout.write("> ");

  String input = stdin.readLineSync() ?? (throw Exception("Unable to read stdin."));

  switch (commandParser.peg(input)) {
    case Success(value: (Command.truthTable, String textProposition)):
      switch (propositionParser.peg(textProposition)) {
        case Success<Proposition>(value: Proposition proposition):
          Iterable<VariableProposition> variables = proposition.variables();
          Table table = generateTable(proposition);

          String renderedTable = renderTable(table);
          String decision = generateDecision(proposition, table);

          stdout.writeln("Your proposition is: $proposition");
          stdout.writeln("The variables are: $variables");
          stdout.writeln(renderedTable);
          stdout.writeln("The proposition is: $decision");

          break;
        case Failure failure:
          String message = failure.generateFailureMessage();

          stdout.writeln("Failure in parsing.");
          stdout.writeln(message);

          break;
        case Empty():
        default:
          break;
      }
      break;
    case Success(value: (Command.argument, String args)):
      switch (argumentParser.peg(args)) {
        case Success(value: (List<Proposition> premises, Proposition conclusion)):
          Proposition left = premises.reduce((a, b) => a & b);
          Proposition right = conclusion;
          Proposition proposition = left.then(right);

          Table table = generateTable(proposition);
          String renderedTable = renderTable(table);
      
          stdout.writeln("Your proposition is: $proposition");
          stdout.writeln(renderedTable);
          break;
        case Failure failure:
          String message = failure.generateFailureMessage();

          stdout.writeln("Failure in parsing.");
          stdout.writeln(message);

          break;
        case Empty():
        default:
          break;
      }
    case Failure failure:
      String message = failure.generateFailureMessage();

      stdout.writeln(message);

      break;
    case Empty():
    default:
      break;
  }
}

/// Yields all the possible combinations of 0 and 1
///   of all the [variables].
/// 
/// Should result in 2^n [Environment] objects where
///   n is the amount of variables.
Iterable<Environment> generateEnvironments(List<VariableProposition> variables) sync* {
  if (variables.isEmpty) {
    yield {};
    return;
  } 
  
  var [VariableProposition first, ...List<VariableProposition> rest] = variables;
  for (Environment remaining in generateEnvironments(rest)) {
    yield {first: true, ...remaining};
    yield {first: false, ...remaining};
  }
}

Row generateRow(Proposition root, Environment environment) {
  Row map = {
    for (Proposition proposition in root.traverse()) //
      proposition: proposition.evaluate(environment),
  };

  return map;
}
  
Table generateTable(Proposition root) {
  Table table = [];
  List<VariableProposition> variables = root.variables().toList();
  Iterable<Environment> environments = generateEnvironments(variables);

  for (Environment environment in environments) {
    table.add(generateRow(root, environment));
  }

  return table;
}

String generateDecision(Proposition root, Table table) {
  Set<bool> results = table.map((r) => r[root] ?? false).toSet();

  if (results.length == 1) {
    if (results.contains(true)) {
      return "Tautology";
    } else {
      return "Contradiction";
    }
  }
  return "Contingent";
}

String renderTable(Table table) {
  /// Takes the keys that are common between all the rows,
  ///   and sorts it by their comparison.
  List<Proposition> keys = table //
      .map((row) => row.keys.toSet())
      .reduce((a, b) => a.intersection(b))
      .toList()
    ..sort((a, b) => a.weight - b.weight);

  /// The table width.
  int width = keys.length;

  /// This is the basic string matrix that will be used in
  ///   determining the maximum length of each column.
  List<List<String>> matrix = [
    [for (Proposition repr in keys) repr.repr().parenthesize()],
    for (Row row in table) [for (Proposition key in keys) (row[key] ?? false) ? "1" : "0"]
  ];

  /// This contains all the maximum widths in each column.
  List<int> profile = [
    for (int x = 0; x < width; ++x) //
      matrix //
          .map((r) => r[x].length)
          .reduce((a, b) => a > b ? a : b),
  ];

  /// This is the final matrix that will be used in
  ///   rendering the table.
  List<List<String>> paddedMatrix = [
    [for (int x = 0; x < width; ++x) matrix[0][x].padCenter(profile[x])],
    [for (int x = 0; x < width; ++x) "-" * profile[x]],
    for (List<String> row in matrix.sublist(1)) //
      [for (int x = 0; x < width; ++x) row[x].padCenter(profile[x])]
  ];

  StringBuffer buffer = StringBuffer();
  for (List<String> row in paddedMatrix) {
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
