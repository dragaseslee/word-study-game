extends HBoxContainer

@onready var rank_label: Label = $RankLabel
@onready var name_label: Label = $NameLabel
@onready var status_label: Label = $StatusLabel


func setup(rank: int, player_name: String, status_text: String) -> void:
    rank_label.text = "%d." % rank
    name_label.text = player_name
    status_label.text = status_text
