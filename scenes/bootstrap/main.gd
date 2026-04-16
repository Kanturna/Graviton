extends Node

# Bootstrap-Entry. Minimal gehalten: es werden keine Services hier
# konfiguriert, weil das Testbed das selbst tut (siehe orbit_testbed.gd).
# Main existiert als dedizierter Einstiegspunkt fuer spaetere Szenenwahl
# (z. B. Spielmodi, Auswahlmenue), die es im Foundation-Slice noch nicht gibt.

const TESTBED_PATH: String = "res://scenes/testbeds/orbit_testbed.tscn"


func _ready() -> void:
	call_deferred("_goto_testbed")


func _goto_testbed() -> void:
	get_tree().change_scene_to_file(TESTBED_PATH)
