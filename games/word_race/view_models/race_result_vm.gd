class_name RaceResultVM
extends ViewModel

var _results: Array[Dictionary] = []


func _on_initialize(config: Dictionary) -> void:
    var results := config.get("results", []) as Array
    for result in results:
        _results.append((result as Dictionary).duplicate(true))


func replay() -> void:
    SceneRouter.goto_game_setting("word_race")


func back_to_hub() -> void:
    SceneRouter.goto_hub()


func build_view_data() -> Dictionary:
    return {
        "results": _results,
    }
