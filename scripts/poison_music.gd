extends RefCounted

const POISON_MUSIC_SCENE := preload("res://audio/music/poison_music.tscn")
const POISON_MUSIC_NODE_PATH := ^"PoisonMusic"
const POISON_MUSIC_PENDING_META := &"poison_music_pending"


static func ensure_playing(tree: SceneTree) -> AudioStreamPlayer2D:
	var root := tree.root
	var player := root.get_node_or_null(POISON_MUSIC_NODE_PATH) as AudioStreamPlayer2D
	if player != null and player.is_queued_for_deletion():
		player = null
	if player == null and root.has_meta(POISON_MUSIC_PENDING_META):
		var pending = root.get_meta(POISON_MUSIC_PENDING_META)
		if pending is AudioStreamPlayer2D and is_instance_valid(pending) and not pending.is_queued_for_deletion():
			player = pending as AudioStreamPlayer2D
	if player == null:
		player = POISON_MUSIC_SCENE.instantiate() as AudioStreamPlayer2D
		root.set_meta(POISON_MUSIC_PENDING_META, player)
		player.tree_entered.connect(func() -> void:
			if root.has_meta(POISON_MUSIC_PENDING_META) and root.get_meta(POISON_MUSIC_PENDING_META) == player:
				root.remove_meta(POISON_MUSIC_PENDING_META)
			if not player.playing:
				player.play()
		, CONNECT_ONE_SHOT)
		root.call_deferred("add_child", player)
		return player
	if not player.playing:
		if player.is_inside_tree():
			player.play()
		else:
			player.call_deferred("play")
	return player


static func stop(tree: SceneTree) -> void:
	var root := tree.root
	if root.has_meta(POISON_MUSIC_PENDING_META):
		var pending = root.get_meta(POISON_MUSIC_PENDING_META)
		if pending is AudioStreamPlayer2D and is_instance_valid(pending):
			(pending as AudioStreamPlayer2D).free()
		root.remove_meta(POISON_MUSIC_PENDING_META)
	var player := tree.root.get_node_or_null(POISON_MUSIC_NODE_PATH) as AudioStreamPlayer2D
	if player == null:
		return
	player.stop()
	player.queue_free()
