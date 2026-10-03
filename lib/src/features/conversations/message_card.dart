import 'package:flutter/foundation.dart';

/// What a reply made, as a pointer: "creation X" or "flow Y".
///
/// The thing itself lives in its own store (creations, flows); the message only
/// remembers which one, so editing or deleting it elsewhere is reflected here
/// and a deleted one simply shows nothing.
@immutable
class MessageCard {
  const MessageCard(this.kind, this.id);

  const MessageCard.creation(String id) : this(MessageCardKind.creation, id);
  const MessageCard.flow(String id) : this(MessageCardKind.flow, id);

  final MessageCardKind kind;
  final String id;

  Map<String, Object?> toJson() => {'kind': kind.name, 'id': id};

  /// Null for anything that is not a card this version knows.
  static MessageCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind =
        MessageCardKind.values.where((k) => k.name == raw['kind']).firstOrNull;
    final id = raw['id'];
    if (kind == null || id is! String || id.isEmpty) return null;
    return MessageCard(kind, id);
  }

  @override
  bool operator ==(Object other) =>
      other is MessageCard && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

enum MessageCardKind { creation, flow }
