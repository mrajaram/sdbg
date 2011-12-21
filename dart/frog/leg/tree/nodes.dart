// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

interface Visitor<R> {
  R visitBlock(Block node);
  R visitClassNode(ClassNode node);
  R visitConditional(Conditional node);
  R visitDoWhile(DoWhile node);
  R visitExpressionStatement(ExpressionStatement node);
  R visitFor(For node);
  R visitFunctionExpression(FunctionExpression node);
  R visitIdentifier(Identifier node);
  R visitIf(If node);
  R visitLiteralBool(LiteralBool node);
  R visitLiteralDouble(LiteralDouble node);
  R visitLiteralInt(LiteralInt node);
  R visitLiteralList(LiteralList node);
  R visitLiteralNull(LiteralNull node);
  R visitLiteralString(LiteralString node);
  R visitModifiers(Modifiers node);
  R visitNewExpression(NewExpression node);
  R visitNodeList(NodeList node);
  R visitOperator(Operator node);
  R visitParenthesizedExpression(ParenthesizedExpression node);
  R visitReturn(Return node);
  R visitSend(Send node);
  R visitSendSet(SendSet node);
  R visitStringInterpolation(StringInterpolation node);
  R visitStringInterpolationPart(StringInterpolationPart node);
  R visitThrow(Throw node);
  R visitTypeAnnotation(TypeAnnotation node);
  R visitVariableDefinitions(VariableDefinitions node);
  R visitWhile(While node);
}

Token firstBeginToken(Node first, Node second) {
  return (first !== null) ? first.getBeginToken()
                          : second.getBeginToken();
}

/**
 * A node in a syntax tree.
 *
 * The abstract part of "abstract syntax tree" is invalidated when
 * supporting tools such as code formatting. These tools need concrete
 * syntax such as parentheses and no constant folding.
 *
 * We support these tools by storing additional references back to the
 * token stream. These references are stored in fields ending with
 * "Token".
 */
class Node implements Hashable {
  final int _hashCode;
  static int _HASH_COUNTER = 0;

  Node() : _hashCode = ++_HASH_COUNTER;

  hashCode() => _hashCode;

  abstract accept(Visitor visitor);

  abstract visitChildren(Visitor visitor);

  toString() => unparse();

  String getObjectDescription() => super.toString();

  String unparse() {
    Unparser unparser = new Unparser();
    try {
      return unparser.unparse(this);
    } catch (var e) {
      return '<<unparse error: ${getObjectDescription()}: ${unparser.sb}>>';
    }
  }

  abstract Token getBeginToken();

  abstract Token getEndToken();

  Block asBlock() => null;
  ClassNode asClassNode() => null;
  Conditional asConditional() => null;
  DoWhile asDoWhile() => null;
  ExpressionStatement asExpressionStatement() => null;
  For asFor() => null;
  FunctionExpression asFunctionExpression() => null;
  Identifier asIdentifier() => null;
  If asIf() => null;
  LiteralBool asLiteralBool() => null;
  LiteralDouble asLiteralDouble() => null;
  LiteralInt asLiteralInt() => null;
  LiteralNull asLiteralNull() => null;
  LiteralString asLiteralString() => null;
  LiteralList asLiteralList() => null;
  Modifiers asModifiers() => null;
  NodeList asNodeList() => null;
  Operator asOperator() => null;
  ParenthesizedExpression asParenthesizedExpression() => null;
  Return asReturn() => null;
  Send asSend() => null;
  SendSet asSendSet() => null;
  StringInterpolation asStringInterpolation() => null;
  StringInterpolationPart asStringInterpolationPart() => null;
  Throw asThrow() => null;
  TypeAnnotation asTypeAnnotation() => null;
  VariableDefinitions asVariableDefinitions() => null;
  While asWhile() => null;
}

class ClassNode extends Node {
  final Identifier name;
  final TypeAnnotation superclass;
  final NodeList interfaces;

  final Token beginToken;
  final Token extendsKeyword;
  final Token endToken;

  ClassNode(this.name, this.superclass, this.interfaces,
            this.beginToken, this.extendsKeyword, this.endToken);

  ClassNode asClassNode() => this;

  accept(Visitor visitor) => visitor.visitClassNode(this);

  visitChildren(Visitor visitor) {
    if (name !== null) name.accept(visitor);
    if (superclass !== null) superclass.accept(visitor);
    if (interfaces !== null) interfaces.accept(visitor);
  }

  bool get isInterface() => beginToken.stringValue === 'interface';

  bool get isClass() => !isInterface;

  Token getBeginToken() => beginToken;

  Token getEndToken() => endToken;
}

class Expression extends Node {
  Expression();
}

class Statement extends Node {
  Statement();
}

/**
 * A message send aka method invocation. In Dart, most operations can
 * (and should) be considered as message sends. Getters and setters
 * are just methods with a special syntax. Consequently, we model
 * property access, assignment, operators, and method calls with this
 * one node.
 */
class Send extends Expression {
  final Node receiver;
  final Node selector;
  final NodeList argumentsNode;
  Link<Node> get arguments() => argumentsNode.nodes;

  Send([this.receiver, this.selector, this.argumentsNode]);
  Send.postfix(this.receiver, this.selector, [Node argument = null])
      : argumentsNode = (argument === null)
        ? new Postfix()
        : new Postfix.singleton(argument);
  Send.prefix(this.receiver, this.selector, [Node argument = null])
      : argumentsNode = (argument === null)
        ? new Prefix()
        : new Prefix.singleton(argument);

  Send asSend() => this;

  accept(Visitor visitor) => visitor.visitSend(this);

  visitChildren(Visitor visitor) {
    if (receiver !== null) receiver.accept(visitor);
    if (selector !== null) selector.accept(visitor);
    if (argumentsNode !== null) argumentsNode.accept(visitor);
  }

  int argumentCount() => argumentsNode.length();

  bool get isOperator() => selector is Operator;
  bool get isPropertyAccess() => argumentsNode === null;
  bool get isFunctionObjectInvocation() => selector === null;
  bool get isPrefix() => argumentsNode is Prefix;
  bool get isPostfix() => argumentsNode is Postfix;
  bool get isIndex() =>
      isOperator && selector.asOperator().source.stringValue === '[]';

  Token getBeginToken() {
    return firstBeginToken(receiver, selector);
  }

  Token getEndToken() {
    Token token;
    if (argumentsNode !== null) token = argumentsNode.getEndToken();
    if (token !== null) return token;
    if (selector !== null) {
      return selector.getEndToken();
    }
    return receiver.getBeginToken();
  }

  Send copyWithReceiver(Node receiver) {
    return new Send(receiver, selector, argumentsNode);
  }
}

class Postfix extends NodeList {
  // TODO(floitsch): pass const EmptyLink<Node>() to super.
  // This currently doesn't work because of a bug of Frog.
  Postfix() : super(null);
  Postfix.singleton(Node argument) : super.singleton(argument);
}

class Prefix extends NodeList {
  // TODO(floitsch): pass const EmptyLink<Node>() to super.
  // This currently doesn't work because of a bug of Frog.
  Prefix() : super(null);
  Prefix.singleton(Node argument) : super.singleton(argument);
}

class SendSet extends Send {
  final Operator assignmentOperator;
  SendSet(receiver, selector, this.assignmentOperator, argumentsNode)
    : super(receiver, selector, argumentsNode);
  SendSet.postfix(receiver,
                  selector,
                  this.assignmentOperator,
                  [Node argument = null])
      : super.postfix(receiver, selector, argument);
  SendSet.prefix(receiver,
                 selector,
                 this.assignmentOperator,
                 [Node argument = null])
      : super.prefix(receiver, selector, argument);

  SendSet asSendSet() => this;

  accept(Visitor visitor) => visitor.visitSendSet(this);

  visitChildren(Visitor visitor) {
    super.visitChildren(visitor);
    if (assignmentOperator !== null) assignmentOperator.accept(visitor);
  }

  Send copyWithReceiver(Node receiver) {
    throw 'not implemented';
  }
}

class NewExpression extends Expression {
  /** The token NEW or CONST */
  final Token newToken;

  // Note: we expect that send.receiver is null.
  final Send send;

  NewExpression([this.newToken, this.send]);

  accept(Visitor visitor) => visitor.visitNewExpression(this);

  visitChildren(Visitor visitor) {
    if (send !== null) send.accept(visitor);
  }

  Token getBeginToken() => newToken;

  Token getEndToken() => send.getEndToken();
}

class NodeList extends Node {
  // TODO(floitsch): don't make nodes private. This is needed, because we
  // work around a bug in Frog that doesn't allow to initialize the field
  // with a const object.
  final Link<Node> _nodes;
  Link<Node> get nodes() => _nodes !== null ? _nodes : const EmptyLink<Node>();
  final Token beginToken;
  final Token endToken;
  final SourceString delimiter;
  bool isEmpty() => nodes.isEmpty();

  // TODO(floitsch): second argument should be this.nodes.
  NodeList([this.beginToken, nodes, this.endToken, this.delimiter])
      : _nodes = nodes;

  NodeList.singleton(Node node) : this(null, new Link<Node>(node));
  NodeList.empty() : this(null, const EmptyLink<Node>());

  NodeList asNodeList() => this;

  int length() {
    int length = 0;
    for (Link<Node> cursor = _nodes; !cursor.isEmpty(); cursor = cursor.tail) {
      length++;
    }
    return length;
  }

  accept(Visitor visitor) => visitor.visitNodeList(this);

  visitChildren(Visitor visitor) {
    if (nodes === null) return;
    for (Link<Node> link = nodes; !link.isEmpty(); link = link.tail) {
      if (link.head !== null) link.head.accept(visitor);
    }
  }

  Token getBeginToken() {
    if (beginToken !== null) return beginToken;
     if (nodes !== null) {
       for (Link<Node> link = nodes; !link.isEmpty(); link = link.tail) {
         if (link.head.getBeginToken() !== null) {
           return link.head.getBeginToken();
         }
         if (link.head.getEndToken() !== null) {
           return link.head.getEndToken();
         }
       }
     }
    return endToken;
  }

  Token getEndToken() {
    if (endToken !== null) return endToken;
    if (nodes !== null) {
      Link<Node> link = nodes;
      if (link.isEmpty()) return beginToken;
      while (!link.tail.isEmpty()) link = link.tail;
      if (link.head.getEndToken() !== null) return link.head.getEndToken();
      if (link.head.getBeginToken() !== null) return link.head.getBeginToken();
    }
    return beginToken;
  }
}

class Block extends Statement {
  final NodeList statements;

  Block(this.statements);

  Block asBlock() => this;

  accept(Visitor visitor) => visitor.visitBlock(this);

  visitChildren(Visitor visitor) {
    if (statements !== null) statements.accept(visitor);
  }

  Token getBeginToken() => statements.getBeginToken();

  Token getEndToken() => statements.getEndToken();
}

class If extends Statement {
  final ParenthesizedExpression condition;
  final Statement thenPart;
  final Statement elsePart;

  final Token ifToken;
  final Token elseToken;

  If(this.condition, this.thenPart, this.elsePart,
     this.ifToken, this.elseToken);

  If asIf() => this;

  bool get hasElsePart() => elsePart !== null;

  void validate() {
    // TODO(ahe): Check that condition has size one.
  }

  accept(Visitor visitor) => visitor.visitIf(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (thenPart !== null) thenPart.accept(visitor);
    if (elsePart !== null) elsePart.accept(visitor);
  }

  Token getBeginToken() => ifToken;

  Token getEndToken() {
    if (elsePart === null) return thenPart.getEndToken();
    return elsePart.getEndToken();
  }
}

class Conditional extends Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  final Token questionToken;
  final Token colonToken;

  Conditional(this.condition, this.thenExpression,
              this.elseExpression, this.questionToken, this.colonToken);

  Conditional asConditional() => this;

  accept(Visitor visitor) => visitor.visitConditional(this);

  visitChildren(Visitor visitor) {
    condition.accept(visitor);
    thenExpression.accept(visitor);
    elseExpression.accept(visitor);
  }

  Token getBeginToken() => condition.getBeginToken();

  Token getEndToken() => elseExpression.getEndToken();
}

class For extends Loop {
  /** Either a variable declaration or an expression. */
  final Node initializer;
  /** Either an expression statement or an empty statement. */
  final Statement conditionStatement;
  final Node update; // TODO(ahe): Should be an expression list.

  final Token forToken;

  For(this.initializer, this.conditionStatement, this.update, body,
      this.forToken) : super(body);

  For asFor() => this;

  Expression get condition() {
    if (conditionStatement is ExpressionStatement) {
      return conditionStatement.asExpressionStatement().expression;
    } else {
      return null;
    }
  }

  accept(Visitor visitor) => visitor.visitFor(this);

  visitChildren(Visitor visitor) {
    if (initializer !== null) initializer.accept(visitor);
    if (conditionStatement !== null) conditionStatement.accept(visitor);
    if (update !== null) update.accept(visitor);
  }

  Token getBeginToken() => forToken;

  Token getEndToken() {
    return body.getEndToken();
  }
}

class FunctionExpression extends Expression {
  final Node name;
  final NodeList parameters;
  final Statement body;
  final TypeAnnotation returnType;
  final Modifiers modifiers;
  final NodeList initializers;

  FunctionExpression(this.name, this.parameters, this.body, this.returnType,
                     this.modifiers, this.initializers);

  FunctionExpression asFunctionExpression() => this;

  accept(Visitor visitor) => visitor.visitFunctionExpression(this);

  visitChildren(Visitor visitor) {
    if (name !== null) name.accept(visitor);
    if (parameters !== null) parameters.accept(visitor);
    if (body !== null) body.accept(visitor);
    if (returnType !== null) returnType.accept(visitor);
  }

  Token getBeginToken() {
    return firstBeginToken(returnType, name);
  }

  Token getEndToken() => body.getEndToken();
}

typedef void DecodeErrorHandler(Token token, var error);

class Literal<T> extends Expression {
  final Token token;
  final DecodeErrorHandler handler;

  Literal(Token this.token, DecodeErrorHandler this.handler);

  abstract T get value();

  visitChildren(Visitor visitor) {}

  Token getBeginToken() => token;

  Token getEndToken() => token;
}

class LiteralInt extends Literal<int> {
  LiteralInt(Token token, DecodeErrorHandler handler) : super(token, handler);

  LiteralInt asLiteralInt() => this;

  int get value() {
    try {
      return Math.parseInt(token.value.toString());
    } catch (BadNumberFormatException ex) {
      (this.handler)(token, ex);
    }
  }

  accept(Visitor visitor) => visitor.visitLiteralInt(this);
}

class LiteralDouble extends Literal<double> {
  LiteralDouble(Token token, DecodeErrorHandler handler)
    : super(token, handler);

  LiteralDouble asLiteralDouble() => this;

  double get value() {
    try {
      return Math.parseDouble(token.value.toString());
    } catch (BadNumberFormatException ex) {
      (this.handler)(token, ex);
    }
  }

  accept(Visitor visitor) => visitor.visitLiteralDouble(this);
}

class LiteralBool extends Literal<bool> {
  LiteralBool(Token token, DecodeErrorHandler handler) : super(token, handler);

  LiteralBool asLiteralBool() => this;

  bool get value() {
    switch (token.value) {
      case Keyword.TRUE: return true;
      case Keyword.FALSE: return false;
      default:
        (this.handler)(token, "not a bool ${token.value}");
    }
  }

  accept(Visitor visitor) => visitor.visitLiteralBool(this);
}

class LiteralString extends Literal<SourceString> {
  LiteralString(Token token) : super(token, null);

  LiteralString asLiteralString() => this;

  SourceString get value() => token.value;

  accept(Visitor visitor) => visitor.visitLiteralString(this);
}

class LiteralNull extends Literal<SourceString> {
  LiteralNull(Token token) : super(token, null);

  LiteralNull asLiteralNull() => this;

  SourceString get value() => null;

  accept(Visitor visitor) => visitor.visitLiteralNull(this);
}

class LiteralList extends Expression {
  final TypeAnnotation type;
  final NodeList elements;

  LiteralList(this.type, this.elements);
  LiteralList asLiteralList() => this;
  accept(Visitor visitor) => visitor.visitLiteralList(this);

  getBeginToken() => firstBeginToken(type, elements);
  getEndToken() => elements.getEndToken();
}

class Identifier extends Expression {
  final Token token;

  SourceString get source() => token.value;

  Identifier(Token this.token);
  Identifier.synthetic(String name) : token = new StringToken(null, name, null);

  bool isThis() => source.stringValue == 'this';

  Identifier asIdentifier() => this;

  accept(Visitor visitor) => visitor.visitIdentifier(this);

  visitChildren(Visitor visitor) {}

  getBeginToken() => token;

  getEndToken() => token;
}

class Operator extends Identifier {
  Operator(Token token) : super(token);
  Operator.synthetic(String name) : super.synthetic(name);

  Operator asOperator() => this;

  accept(Visitor visitor) => visitor.visitOperator(this);
}

class Return extends Statement {
  final Expression expression;
  final Token beginToken;
  final Token endToken;

  Return(this.beginToken, this.endToken, this.expression);

  Return asReturn() => this;

  bool get hasExpression() => expression !== null;

  accept(Visitor visitor) => visitor.visitReturn(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => beginToken;

  Token getEndToken() => endToken;
}

class ExpressionStatement extends Statement {
  final Expression expression;
  final Token endToken;

  ExpressionStatement(this.expression, this.endToken);

  ExpressionStatement asExpressionStatement() => this;

  accept(Visitor visitor) => visitor.visitExpressionStatement(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => endToken;
}

class Throw extends Statement {
  final Expression expression;

  final Token throwToken;
  final Token endToken;

  Throw(this.expression, this.throwToken, this.endToken);

  Throw asThrow() => this;

  accept(Visitor visitor) => visitor.visitThrow(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => throwToken;

  Token getEndToken() => endToken;
}

class TypeAnnotation extends Node {
  final Identifier typeName;
  final NodeList typeArguments;

  TypeAnnotation(Identifier this.typeName, NodeList this.typeArguments);

  TypeAnnotation asTypeAnnotation() => this;

  accept(Visitor visitor) => visitor.visitTypeAnnotation(this);

  visitChildren(Visitor visitor) {
    typeName.accept(visitor);
    if (typeArguments !== null) typeArguments.accept(visitor);
  }

  Token getBeginToken() => typeName.getBeginToken();

  Token getEndToken() => typeName.getEndToken();
}

class VariableDefinitions extends Statement {
  final Token endToken;
  final TypeAnnotation type;
  final Modifiers modifiers;
  final NodeList definitions;
  VariableDefinitions(this.type, this.modifiers, this.definitions,
                      this.endToken);

  VariableDefinitions asVariableDefinitions() => this;

  accept(Visitor visitor) => visitor.visitVariableDefinitions(this);

  visitChildren(Visitor visitor) {
    if (type !== null) type.accept(visitor);
    if (definitions !== null) definitions.accept(visitor);
  }

  Token getBeginToken() {
    return firstBeginToken(type, definitions);
  }

  Token getEndToken() => endToken;
}

class Loop extends Statement {
  abstract Expression get condition();
  final Statement body;

  Loop(this.body);
}

class DoWhile extends Loop {
  final Token doKeyword;
  final Token whileKeyword;
  final Token endToken;

  final Expression condition;

  DoWhile(Statement body, Expression this.condition,
          Token this.doKeyword, Token this.whileKeyword, Token this.endToken)
    : super(body);

  DoWhile asDoWhile() => this;

  accept(Visitor visitor) => visitor.visitDoWhile(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  Token getBeginToken() => doKeyword;

  Token getEndToken() => endToken;
}

class While extends Loop {
  final Token whileKeyword;
  final Expression condition;

  While(Expression this.condition, Statement body,
        Token this.whileKeyword) : super(body);

  While asWhile() => this;

  accept(Visitor visitor) => visitor.visitWhile(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  Token getBeginToken() => whileKeyword;

  Token getEndToken() => body.getEndToken();
}

class ParenthesizedExpression extends Expression {
  final Expression expression;
  final BeginGroupToken beginToken;

  ParenthesizedExpression(Expression this.expression,
                          BeginGroupToken this.beginToken);

  ParenthesizedExpression asParenthesizedExpression() => this;

  accept(Visitor visitor) => visitor.visitParenthesizedExpression(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => beginToken;

  Token getEndToken() => beginToken.endGroup;
}

/** Representation of modifiers such as static, abstract, final, etc. */
class Modifiers extends Node {
  /* TODO(ahe): The following should be validated relating to modifiers:
   * 1. The nodes must come in a certain order.
   * 2. The keywords "var" and "final" may not be used at the same time.
   * 3. The type of an element must be null if isVar() is true.
   */

  final NodeList nodes;
  /** Bit pattern to easy check what modifiers are present. */
  final int flags;

  static final int FLAG_STATIC = 1;
  static final int FLAG_ABSTRACT = FLAG_STATIC << 1;
  static final int FLAG_FINAL = FLAG_ABSTRACT << 1;
  static final int FLAG_VAR = FLAG_FINAL << 1;
  static final int FLAG_CONST = FLAG_VAR << 1;

  Modifiers(NodeList nodes)
    : this.nodes = nodes, flags = computeFlags(nodes.nodes);

  static int computeFlags(Link<Node> nodes) {
    int flags = 0;
    for (; !nodes.isEmpty(); nodes = nodes.tail) {
      String value = nodes.head.asIdentifier().source.stringValue;
      if (value === 'static') flags += FLAG_STATIC;
      else if (value === 'abstract') flags += FLAG_ABSTRACT;
      else if (value === 'final') flags += FLAG_FINAL;
      else if (value === 'var') flags += FLAG_VAR;
      else if (value === 'const') flags += FLAG_CONST;
    }
    return flags;
  }

  Modifiers asModifiers() => this;
  Token getBeginToken() => nodes.getBeginToken();
  Token getEndToken() => nodes.getEndToken();
  accept(Visitor visitor) => visitor.visitModifiers(this);
  visitChildren(Visitor visitor) => nodes.accept(visitor);

  bool isStatic() => (flags & FLAG_STATIC) != 0;
  bool isAbstract() => (flags & FLAG_ABSTRACT) != 0;
  bool isFinal() => (flags & FLAG_FINAL) != 0;
  bool isVar() => (flags & FLAG_VAR) != 0;
  bool isConst() => (flags & FLAG_CONST) != 0;
}

class StringInterpolation extends Expression {
  final LiteralString string;
  final NodeList parts;

  StringInterpolation(this.string, this.parts);

  StringInterpolation asStringInterpolation() => this;

  accept(Visitor visitor) => visitor.visitStringInterpolation(this);

  visitChildren(Visitor visitor) {
    string.accept(visitor);
    parts.accept(visitor);
  }

  Token getBeginToken() => string.getBeginToken();

  Token getEndToken() => parts.getEndToken();
}

class StringInterpolationPart extends Node {
  final Expression expression;
  final LiteralString string;

  StringInterpolationPart(this.expression, this.string);

  StringInterpolationPart asStringInterpolationPart() => this;

  accept(Visitor visitor) => visitor.visitStringInterpolationPart(this);

  visitChildren(Visitor visitor) {
    expression.accept(visitor);
    string.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => string.getEndToken();
}

class UnimplementedExpression extends Expression {
  final String description;
  final NodeList nodes;

  UnimplementedExpression(this.description, List<Node> nodes)
    : this.nodes = new NodeList(null, new Link<Node>.fromList(nodes));

  toString() => '$description($nodes)';

  Token getBeginToken() => nodes.getBeginToken();

  Token getEndToken() => nodes.getEndToken();
}

class UnimplementedStatement extends Statement {
  final String description;
  final NodeList nodes;

  UnimplementedStatement(this.description, List<Node> nodes)
    : this.nodes = new NodeList(null, new Link<Node>.fromList(nodes));

  toString() => '$description($nodes)';

  Token getBeginToken() => nodes.getBeginToken();

  Token getEndToken() => nodes.getEndToken();
}
