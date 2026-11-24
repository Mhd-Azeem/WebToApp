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
	var crowd = scene.pedestrians
	crowd.graphics_tier=3
	for i in range(33): await physics_frame
	check(crowd.actors.size()==9,"High tier allocates a limited pool")
	var first: CharacterBody3D=crowd.actors[0].body
	var before := first.position
	for i in range(70): await physics_frame
	check(first.position.distance_to(before)>0.2,"Pedestrian follows a sidewalk routine")
	crowd.graphics_tier=0
	crowd._refresh()
	check(crowd.actors.size()==9 and not crowd.actors[8].body.visible,"Low tier recycles dormant actors")
	crowd.raining=true
	crowd._refresh()
	check(not first.visible,"Rain reduces outdoor population")
	crowd.raining=false
	crowd._refresh()
	check(crowd.actors[0].body==first and first.visible,"Pedestrian pool reuses its original bodies")
	await scene.on_foot.toggle(false)
	scene.on_foot.person.position=first.position+Vector3(0,0,1)
	check(crowd.interact(),"Nearby pedestrian opens contextual dialogue")
	crowd.respond("Ask for directions")
	check(crowd.dialogue.text.contains(":"),"Directions use the pedestrian's authored line")
	crowd.respond("Greet")
	check(crowd.relationships.get_value("friendship","Nirmala",0)>=2,"Conversations persist friendship progress")
	crowd.respond("Close")
	check(not crowd.panel.visible and crowd.active_index==-1,"Closing dialogue resumes the routine")
	scene.queue_free()
	await process_frame
	print("Nearby pedestrian simulation and dialogue: ", "PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)
