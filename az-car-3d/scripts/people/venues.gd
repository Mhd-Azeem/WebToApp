extends Node3D

const G = preload("res://scripts/geometry.gd")
const LOCATIONS := [Vector3(46,0,120),Vector3(127,0,66)]
const NAMES := ["Fort Tea Room","Paddy Lane Grocer"]
const ITEMS := ["Ceylon tea","Market provisions"]
const PRICES := [8,14]
var rooms := {}
var active_site := -1
var status: Label
var person: CharacterBody3D
var game: Node

func setup(layer: CanvasLayer, player: CharacterBody3D, progress: Node) -> void:
	person=player
	game=progress
	status=Label.new()
	status.position=Vector2(21,58)
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	status.hide()
	for i in range(LOCATIONS.size()): _facade(i)

func _facade(i: int) -> void:
	var base: Vector3=LOCATIONS[i]
	var plaster := G.material("plaster",Color(0.85,0.78,0.64))
	var timber := G.material("",Color(0.16,0.26,0.24))
	var roof := G.material("tiles",Color(0.72,0.62,0.54))
	var glass := G.material("",Color(0.31,0.47,0.52))
	var shell := Node3D.new()
	add_child(shell)
	shell.position=base
	G.box(shell,Vector3(0,0.025,0),Vector3(8.6,0.13,8.3),G.material("concrete"),true)
	G.box(shell,Vector3(0,1.53,-4),Vector3(8.4,3.0,0.18),plaster,true)
	for side in [-1,1]:
		G.box(shell,Vector3(side*4.1,1.53,0),Vector3(0.19,3.0,8),plaster,true)
		G.box(shell,Vector3(side*2.56,1.51,4),Vector3(3.01,2.97,0.20),plaster,true)
		G.box(shell,Vector3(side*2.56,1.72,4.14),Vector3(2.22,1.25,0.085),timber)
		G.box(shell,Vector3(side*2.56,1.72,4.19),Vector3(2.08,1.12,0.035),glass)
		G.box(shell,Vector3(side*1.05,1.32,4.15),Vector3(0.10,2.45,0.10),timber)
	G.box(shell,Vector3(0,2.79,4),Vector3(2.14,0.46,0.21),plaster,true)
	for side in [-1,1]:
		var panel := G.box(shell,Vector3(0,3.26,side*2.03),Vector3(8.9,0.16,4.55),roof)
		panel.rotation.x=side*0.13
	G.box(shell,Vector3(0,2.47,4.49),Vector3(8.1,0.09,1.08),roof)
	var sign := G.label(shell,NAMES[i],Vector3(0,2.83,4.15),24)
	sign.pixel_size=0.014

func update(walking: bool) -> void:
	if not walking:
		status.hide()
		_release_rooms()
		return
	var near := _near_site()
	for index in rooms.keys():
		if index!=near and person.position.distance_to(LOCATIONS[index])>18.0:
			rooms[index].queue_free()
			rooms.erase(index)
	if near>=0 and not rooms.has(near): _furnish(near)
	if active_site!=near:
		active_site=near
		status.text="%s · G / Interact · %s · %d credits" % [NAMES[near],ITEMS[near],PRICES[near]] if near>=0 else ""
	status.visible=near>=0

func _near_site() -> int:
	for i in range(LOCATIONS.size()):
		if person.position.distance_to(LOCATIONS[i])<9.0: return i
	return -1

func _furnish(index: int) -> void:
	var room := Node3D.new()
	add_child(room)
	room.position=LOCATIONS[index]
	rooms[index]=room
	var timber := G.material("",Color(0.40,0.26,0.17))
	var top := G.material("tiles",Color(0.90,0.89,0.80))
	G.box(room,Vector3(0,0.52,-1.9),Vector3(3.6,1.04,0.82),timber,true)
	G.box(room,Vector3(0,1.06,-1.9),Vector3(3.75,0.09,0.97),top)
	for side in [-1,1]:
		G.box(room,Vector3(side*3.18,0.79,1.1),Vector3(0.72,0.09,1.12),timber,true)
		for z in [0.72,1.48]:
			G.box(room,Vector3(side*3.18,0.39,z),Vector3(0.11,0.78,0.11),timber)
	var lamp := OmniLight3D.new()
	lamp.position=Vector3(0,2.62,0)
	lamp.omni_range=5.4
	lamp.light_color=Color(1.0,0.83,0.65)
	lamp.light_energy=0.75
	room.add_child(lamp)

func _release_rooms() -> void:
	for room: Node3D in rooms.values(): room.queue_free()
	rooms.clear()
	active_site=-1

func interact() -> bool:
	if active_site<0: return false
	var local: Vector3=person.position-LOCATIONS[active_site]
	if absf(local.x)>2.4 or local.z < -1.8 or local.z >2.0:
		status.text="Walk in and approach the counter"
		return true
	var cost: int=PRICES[active_site]
	if game.progress.credits<cost:
		status.text="You need %d credits" % cost
		return true
	game.progress.credits-=cost
	game.progress.award("Local customer")
	game.save()
	status.text="%s purchased · %d credits left" % [ITEMS[active_site],game.progress.credits]
	return true
