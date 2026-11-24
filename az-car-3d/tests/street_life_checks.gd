extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool,message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(70): await physics_frame
	await scene.on_foot.toggle(false)
	var walker: CharacterBody3D=scene.on_foot.person
	var venues=scene.venues
	check(venues.rooms.is_empty(),"Shop interiors remain unloaded at spawn")
	walker.position=Vector3(46,0.15,126)
	venues.update(true)
	check(venues.rooms.has(0),"Walking up to the tea room streams its furniture")
	var old_balance: int=scene.gameplay.progress.credits
	check(venues.interact() and scene.gameplay.progress.credits==old_balance,"Exterior prompt leaves credits untouched")
	walker.position=Vector3(46,0.15,120)
	check(venues.interact() and scene.gameplay.progress.credits==old_balance-8,"Tea room purchase uses the existing economy")
	walker.position=Vector3(0,0.2,125)
	venues.update(true)
	check(venues.rooms.is_empty(),"Walking away frees the interior")
	var crowd=scene.pedestrians
	var actor=crowd.actors[0]
	actor.body.position=scene.car.to_global(Vector3(-2.5,0.15,0.21))
	walker.position=actor.body.position+Vector3(0,0,0.7)
	check(crowd.interact(),"Nearby parked car allows a conversation about riding")
	crowd.respond("Invite as passenger")
	check(crowd.rider<0,"A stranger can decline a ride")
	crowd.respond("Greet")
	crowd.respond("Talk")
	crowd.respond("Invite as passenger")
	check(crowd.rider==0 and scene.on_foot.passenger_occupied and actor.body.collision_layer==0,"A friendly pedestrian can occupy the passenger seat")
	crowd.respond("Close")
	walker.position=scene.car.to_global(Vector3(1.65,0.15,0.22))
	check(crowd.drop_passenger() and not scene.on_foot.passenger_occupied,"A stopped car allows the passenger to disembark on clear ground")
	scene.weather_selector.select(1)
	scene._update_weather()
	check(scene.car.wheel_physics.wet_roads and scene.G.material("asphalt").roughness<0.6,"Rain updates both grip and asphalt rendering")
	scene.queue_free()
	await process_frame
	print("Street venues, weather and passenger invitations: ", "PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)
