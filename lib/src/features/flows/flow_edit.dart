import 'package:flutter/foundation.dart';

import 'package:finn_ai/src/features/flows/flow_model.dart';

/// Where in a flow's tree a list of blocks lives: the top level, or one lane of
/// a branch (its "yes" or "otherwise" lane), possibly inside other branches.
@immutable
class FlowLane {
  const FlowLane([this.via = const []]);

  /// The branches walked through to get here, outermost first: block [index]
  /// of the lane so far, and which of its two lanes.
  final List<({int index, bool otherwise})> via;

  static const root = FlowLane();

  /// The lane inside the branch at [index] of this lane.
  FlowLane into(int index, {required bool otherwise}) =>
      FlowLane([...via, (index: index, otherwise: otherwise)]);

  int get depth => via.length;

  @override
  bool operator ==(Object other) =>
      other is FlowLane && listEquals(other.via, via);

  @override
  int get hashCode => Object.hashAll(via);
}

/// Pure edits of a flow's block tree.
///
/// Each returns a new list and never throws on an index that is out of range:
/// a stale tap (the user deleted a block while a sheet was open) must change
/// nothing rather than crash the editor.
abstract final class FlowEdit {
  static List<FlowBlock> insert(
    List<FlowBlock> blocks,
    FlowLane lane,
    int index,
    FlowBlock block,
  ) =>
      _inLane(blocks, lane, 0, (list) {
        final at = index.clamp(0, list.length);
        return [...list.take(at), block, ...list.skip(at)];
      });

  static List<FlowBlock> replace(
    List<FlowBlock> blocks,
    FlowLane lane,
    int index,
    FlowBlock block,
  ) =>
      _inLane(blocks, lane, 0, (list) {
        if (index < 0 || index >= list.length) return list;
        return [...list]..[index] = block;
      });

  static List<FlowBlock> remove(
    List<FlowBlock> blocks,
    FlowLane lane,
    int index,
  ) =>
      _inLane(blocks, lane, 0, (list) {
        if (index < 0 || index >= list.length) return list;
        return [...list]..removeAt(index);
      });

  /// Moves a block by [delta] places within its lane.
  static List<FlowBlock> move(
    List<FlowBlock> blocks,
    FlowLane lane,
    int index,
    int delta,
  ) =>
      _inLane(blocks, lane, 0, (list) {
        final to = index + delta;
        if (index < 0 || index >= list.length || to < 0 || to >= list.length) {
          return list;
        }
        final copy = [...list];
        copy.insert(to, copy.removeAt(index));
        return copy;
      });

  /// The blocks of [lane].
  static List<FlowBlock> laneBlocks(List<FlowBlock> blocks, FlowLane lane) {
    var list = blocks;
    for (final step in lane.via) {
      if (step.index < 0 || step.index >= list.length) return const [];
      final branch = list[step.index];
      list = step.otherwise ? branch.otherwise : branch.then;
    }
    return list;
  }

  /// The block at [index] in [lane], or null.
  static FlowBlock? at(List<FlowBlock> blocks, FlowLane lane, int index) {
    var list = blocks;
    for (final step in lane.via) {
      if (step.index < 0 || step.index >= list.length) return null;
      final branch = list[step.index];
      list = step.otherwise ? branch.otherwise : branch.then;
    }
    return index >= 0 && index < list.length ? list[index] : null;
  }

  /// The block a run-log path (`2`, `1.then.0`) points at, or null when the
  /// flow has been edited since and the path no longer leads anywhere.
  static FlowBlock? atPath(List<FlowBlock> blocks, String path) {
    final parts = path.split('.');
    var list = blocks;
    FlowBlock? current;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part == 'then' || part == 'else') {
        if (current == null) return null;
        list = part == 'then' ? current.then : current.otherwise;
        continue;
      }
      final index = int.tryParse(part);
      if (index == null || index < 0 || index >= list.length) return null;
      current = list[index];
    }
    return current;
  }

  /// Whether another branch may be added in [lane] without going deeper than a
  /// flow may.
  static bool canNestBranch(FlowLane lane) =>
      lane.depth < FlowBlock.maxDepth - 1;

  static List<FlowBlock> _inLane(
    List<FlowBlock> blocks,
    FlowLane lane,
    int level,
    List<FlowBlock> Function(List<FlowBlock>) change,
  ) {
    if (level == lane.via.length) return change(blocks);
    final step = lane.via[level];
    if (step.index < 0 || step.index >= blocks.length) return blocks;
    final branch = blocks[step.index];
    final inner = _inLane(
      step.otherwise ? branch.otherwise : branch.then,
      lane,
      level + 1,
      change,
    );
    return [...blocks]..[step.index] = step.otherwise
        ? branch.copyWith(otherwise: inner)
        : branch.copyWith(then: inner);
  }
}
