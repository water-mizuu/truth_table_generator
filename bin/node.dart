import "dart:collection";
import "dart:math";

extension ParenthesizeExtension on String {
  String parenthesize() => contains(" ") ? "($this)" : this;
}

typedef Environment = Map<Proposition, bool>;

sealed class Proposition {
  const Proposition();

  const factory Proposition.variable(String name) = VariableProposition;
  const factory Proposition.not(Proposition proposition) = NotProposition;
  const factory Proposition.and(Proposition left, Proposition right) = AndProposition;
  const factory Proposition.or(Proposition left, Proposition right) = OrProposition;
  const factory Proposition.xor(Proposition left, Proposition right) = XorProposition;
  const factory Proposition.conditional(Proposition antecedent, Proposition consequent) = IfProposition;
  const factory Proposition.iff(Proposition left, Proposition right) = IffProposition;
  const factory Proposition.argument(Proposition left, Proposition right) = ArgumentProposition;
  const factory Proposition.labeled(String label, Proposition child) = LabeledProposition;

  bool evaluate(Environment env);
  String repr();

  Set<VariableProposition> variables() => _variables.toSet();
  Iterable<Proposition> traverse() sync* {
    Proposition root = this;
    Set<Proposition> seen = {};
    Queue<Proposition> queue = Queue()..add(root);

    while (queue.isNotEmpty) {
      Proposition latest = queue.removeFirst();

      if (seen.add(latest)) {
        yield latest;

        queue.addAll(latest._children);
      }
    }
  }

  int get weight;

  Iterable<Proposition> get _children;
  Iterable<VariableProposition> get _variables;

  @override
  String toString() => repr();

  Proposition then(Proposition other) => Proposition.conditional(this, other);
  Proposition iff(Proposition other) => Proposition.iff(this, other);
  Proposition operator &(Proposition other) => Proposition.and(this, other);
  Proposition operator |(Proposition other) => Proposition.or(this, other);
  Proposition operator ^(Proposition other) => Proposition.xor(this, other);

  LabeledProposition labeled(String name) => LabeledProposition(name, this);
}

class VariableProposition extends Proposition {
  final String name;

  const VariableProposition(this.name);

  @override
  bool evaluate(Environment env) => env[this] ?? false;

  @override
  int get weight => 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield this;
  }

  @override
  Iterable<Proposition> get _children sync* {}

  @override
  String repr() => name;

  @override
  bool operator ==(Object other) => other is VariableProposition && this.name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class NotProposition extends Proposition {
  final Proposition proposition;

  const NotProposition(this.proposition);

  @override
  bool evaluate(Environment env) => switch (proposition.evaluate(env)) {
        true => false,
        false => true,
      };

  @override
  int get weight => proposition.weight + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* proposition._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield proposition;
  }

  @override
  String repr() {
    String proposition = this.proposition.repr().parenthesize();

    return "¬$proposition";
  }

  @override
  bool operator ==(Object other) => other is NotProposition && this.proposition == other.proposition;

  @override
  int get hashCode => ("!", proposition).hashCode;
}

class OrProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const OrProposition(this.left, this.right);

  @override
  bool evaluate(Environment env) => switch ((left.evaluate(env), right.evaluate(env))) {
        (true, true) => true,
        (true, false) => true,
        (false, true) => true,
        (false, false) => false,
      };

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* left._variables;
    yield* right._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ∨ $right";
  }

  @override
  bool operator ==(Object other) =>
      other is OrProposition &&
      ((this.left == other.left && this.right == other.right) || //
          (this.right == other.left && this.left == other.left));

  @override
  int get hashCode => (left, "||", right).hashCode;
}

class AndProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const AndProposition(this.left, this.right);

  @override
  bool evaluate(Environment env) => switch ((left.evaluate(env), right.evaluate(env))) {
        (true, true) => true,
        (true, false) => false,
        (false, true) => false,
        (false, false) => false,
      };

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* left._variables;
    yield* right._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ∧ $right";
  }

  @override
  bool operator ==(Object other) =>
      other is AndProposition &&
      ((this.left == other.left && this.right == other.right) || (this.right == other.left && this.left == other.left));

  @override
  int get hashCode => (left, "&&", right).hashCode;
}

class XorProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const XorProposition(this.left, this.right);

  @override
  bool evaluate(Environment env) => switch ((left.evaluate(env), right.evaluate(env))) {
        (true, true) => false,
        (true, false) => true,
        (false, true) => true,
        (false, false) => false,
      };

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* left._variables;
    yield* right._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ⊕ $right";
  }

  @override
  bool operator ==(Object other) =>
      other is XorProposition &&
      ((this.left == other.left && this.right == other.right) || (this.right == other.left && this.left == other.left));

  @override
  int get hashCode => (left, "^^", right).hashCode;
}

class IfProposition extends Proposition {
  final Proposition antecedent;
  final Proposition consequent;

  const IfProposition(this.antecedent, this.consequent);

  @override
  bool evaluate(Environment env) => switch ((antecedent.evaluate(env), consequent.evaluate(env))) {
        (true, true) => true,
        (true, false) => false,
        (false, true) => true,
        (false, false) => true,
      };

  @override
  int get weight => max(antecedent.weight, consequent.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* antecedent._variables;
    yield* consequent._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield antecedent;
    yield consequent;
  }

  @override
  String repr() {
    String antecedent = this.antecedent.repr().parenthesize();
    String consequent = this.consequent.repr().parenthesize();

    return "$antecedent → $consequent";
  }

  @override
  bool operator ==(Object other) =>
      other is IfProposition && this.antecedent == other.antecedent && this.consequent == other.consequent;

  @override
  int get hashCode => (antecedent, "->", consequent).hashCode;
}

class IffProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const IffProposition(this.left, this.right);

  @override
  bool evaluate(Environment env) => switch ((left.evaluate(env), right.evaluate(env))) {
        (true, true) => true,
        (true, false) => false,
        (false, true) => false,
        (false, false) => true,
      };

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* left._variables;
    yield* right._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ↔ $right";
  }

  @override
  bool operator ==(Object other) =>
      other is IffProposition &&
      ((left == other.left && right == other.right) || (right == other.left && left == other.right));

  @override
  int get hashCode => (left, "<->", right).hashCode;
}

class ArgumentProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const ArgumentProposition(this.left, this.right);

  @override
  bool evaluate(Environment env) {
    if (left.evaluate(env)) {
      return right.evaluate(env);
    } else {
      return true;
    }
  }

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> get _variables sync* {
    yield* left._variables;
    yield* right._variables;
  }

  @override
  Iterable<Proposition> get _children sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ⇒ $right";
  }

  @override
  bool operator ==(Object other) =>
      other is ArgumentProposition && this.left == other.left && this.right == other.right;

  @override
  int get hashCode => (left, "=>", right).hashCode;
}

class LabeledProposition extends Proposition {
  final String label;
  final Proposition child;

  const LabeledProposition(this.label, this.child);

  @override
  Iterable<Proposition> get _children => child._children;

  @override
  Iterable<VariableProposition> get _variables => child._variables;

  @override
  bool evaluate(Environment env) => child.evaluate(env);

  @override
  String repr() => "[$label] $child";

  @override
  int get weight => child.weight * child.weight + label.codeUnits.reduce((a, b) => a + b);

  @override
  bool operator ==(Object other) => (other is LabeledProposition && this.child == other.child) || this.child == other;

  @override
  int get hashCode => child.hashCode;
}
