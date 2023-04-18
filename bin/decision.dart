import "main.dart";
import "node.dart";

enum Decision {
  tautology("Tautology"),
  contradiction("Contradiction"),
  contingent("Contingent");

  final String display;
  const Decision(this.display);

  @override
  String toString() => display;
}

Decision generateDecision(Proposition root, Table table) {
  var (List<Row> rows, _) = table;
  Set<bool> results = rows.map((r) => r[root] ?? false).toSet();

  if (results.length == 1) {
    if (results.contains(true)) {
      return Decision.tautology;
    } else {
      return Decision.contradiction;
    }
  }
  return Decision.contingent;
}
