
import "dart:collection";
import "dart:math";

extension ParenthesizeExtension on String {
  String parenthesize() => contains(" ") ? "($this)" : this;
}

typedef Environment = Map<Proposition, bool>;

sealed class Proposition {
  const Proposition();

  const factory Proposition.not(Proposition proposition) = NotProposition;
  const factory Proposition.and(Proposition left, Proposition right) = AndProposition;
  const factory Proposition.or(Proposition left, Proposition right) = OrProposition;
  const factory Proposition.xor(Proposition left, Proposition right) = XorProposition;
  const factory Proposition.conditional(Proposition antecedent, Proposition consequent) = IfProposition;
  const factory Proposition.iff(Proposition left, Proposition right) = IffProposition;
  const factory Proposition.argument(Proposition left, Proposition right) = ArgumentProposition;

  bool evaluate(Environment environment);
  String repr();

  Set<VariableProposition> variables() => _variables().toSet();
  Iterable<Proposition> traverse() sync* {
    Proposition root = this;
    Set<Proposition> seen = {};
    Queue<Proposition> queue = Queue()..add(root);

    while (queue.isNotEmpty) {
      Proposition latest = queue.removeFirst();

      if (seen.add(latest)) {
        yield latest;

        for (Proposition child in latest._children()) {
          queue.add(child);
        }
      }
    }
  }
  int get weight;

  Iterable<Proposition> _children();
  Iterable<VariableProposition> _variables();

  @override
  String toString() => repr();

  Proposition then(Proposition other) => Proposition.conditional(this, other);
  Proposition operator &(Proposition other) => Proposition.and(this, other);
  Proposition operator |(Proposition other) => Proposition.or(this, other);
  Proposition operator ^(Proposition other) => Proposition.xor(this, other);
}

class VariableProposition extends Proposition {
  final String name;

  const VariableProposition(this.name);
  
  @override
  bool evaluate(Environment environment) => environment[this] ?? false;

  @override
  int get weight => 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield this;
  }

  @override
  Iterable<Proposition> _children() sync* {}

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
  bool evaluate(Environment environment) => !proposition.evaluate(environment);

  @override
  int get weight => proposition.weight + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* proposition._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield proposition;
  }

  @override
  String repr() {
    String proposition = this.proposition.repr().parenthesize();

    return "¬$proposition";
  }
}

class OrProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const OrProposition(this.left, this.right);

  @override
  bool evaluate(Environment environment) => left.evaluate(environment) || right.evaluate(environment);

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* left._variables();
    yield* right._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ∨ $right";
  }
}

class AndProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const AndProposition(this.left, this.right);

  @override
  bool evaluate(Environment environment) => left.evaluate(environment) && right.evaluate(environment);

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* left._variables();
    yield* right._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ∧ $right";
  }
}

class XorProposition extends Proposition {
  final Proposition left;
  final Proposition right;
  
  const XorProposition(this.left, this.right);

  @override
  bool evaluate(Environment environment) => left.evaluate(environment) ^ right.evaluate(environment);

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* left._variables();
    yield* right._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ⊕ $right";
  }
}

class IfProposition extends Proposition {
  final Proposition antecedent;
  final Proposition consequent;

  const IfProposition(this.antecedent, this.consequent);

  @override
  bool evaluate(Environment environment) => !antecedent.evaluate(environment) || consequent.evaluate(environment);

  @override
  int get weight => max(antecedent.weight, consequent.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* antecedent._variables();
    yield* consequent._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield antecedent;
    yield consequent;
  }

  @override
  String repr() {
    String antecedent = this.antecedent.repr().parenthesize();
    String consequent = this.consequent.repr().parenthesize();

    return "$antecedent → $consequent";
  }
}

class IffProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const IffProposition(this.left, this.right);

  @override
  bool evaluate(Environment environment) => left.evaluate(environment) == right.evaluate(environment);

  @override 
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* left._variables();
    yield* right._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ↔ $right";
  }
}

class ArgumentProposition extends Proposition {
  final Proposition left;
  final Proposition right;

  const ArgumentProposition(this.left, this.right);

  @override
  bool evaluate(Environment environment) => !left.evaluate(environment) || right.evaluate(environment);

  @override
  int get weight => max(left.weight, right.weight) * 2 + 1;

  @override
  Iterable<VariableProposition> _variables() sync* {
    yield* left._variables();
    yield* right._variables();
  }

  @override
  Iterable<Proposition> _children() sync* {
    yield left;
    yield right;
  }

  @override
  String repr() {
    String left = this.left.repr().parenthesize();
    String right = this.right.repr().parenthesize();

    return "$left ⇒ $right";
  }
}
