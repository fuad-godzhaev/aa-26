class_name BehaviorTree
extends RefCounted

# A lean Behaviour Tree. Composites are generic; leaves wrap Callables so
# the concrete logic lives with the agent that builds the tree. tick()
# takes a Blackboard and returns one of these statuses.

enum { SUCCESS, FAILURE, RUNNING }


class BTNode extends RefCounted:
	var label: String = "node"
	func tick(_bb: Blackboard) -> int:
		return BehaviorTree.FAILURE


# Runs children in order; returns the first non-FAILURE (priority).
class Selector extends BTNode:
	var children: Array = []
	func tick(bb: Blackboard) -> int:
		for c in children:
			var s: int = c.tick(bb)
			if s != BehaviorTree.FAILURE:
				return s
		return BehaviorTree.FAILURE


# Runs children in order; stops at the first non-SUCCESS.
class Sequence extends BTNode:
	var children: Array = []
	func tick(bb: Blackboard) -> int:
		for c in children:
			var s: int = c.tick(bb)
			if s != BehaviorTree.SUCCESS:
				return s
		return BehaviorTree.SUCCESS


# SUCCESS when the predicate(bb) is true, else FAILURE.
class Condition extends BTNode:
	var predicate: Callable
	func _init(p: Callable, name: String = "cond") -> void:
		predicate = p
		label = name
	func tick(bb: Blackboard) -> int:
		return BehaviorTree.SUCCESS if predicate.call(bb) else BehaviorTree.FAILURE


# Delegates to act(bb), which returns a status.
class Action extends BTNode:
	var act: Callable
	func _init(a: Callable, name: String = "act") -> void:
		act = a
		label = name
	func tick(bb: Blackboard) -> int:
		return act.call(bb)
