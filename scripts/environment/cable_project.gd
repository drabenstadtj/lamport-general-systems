@tool
extends Path3D

@export var ray_height := 50.0
@export var ray_depth := 200.0
@export var collision_mask := 0xffffffff

@export var do_project := false:
	set(_v):
		do_project = false
		project_points_to_collision()

func project_points_to_collision():
	if curve == null:
		push_warning("Path3D has no Curve3D assigned.")
		return

	var world := get_world_3d()
	if world == null:
		push_warning("No World3D available. Make sure this Path3D is in the edited scene tree.")
		return

	var space := world.direct_space_state

	for i in range(curve.point_count):
		# Curve points are LOCAL to the Path3D
		var local_p := curve.get_point_position(i)
		var global_p := global_transform * local_p

		var from := global_p + Vector3.UP * ray_height
		var to := global_p - Vector3.UP * ray_depth

		var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		params.collide_with_bodies = true
		params.collide_with_areas = false

		# Avoid hitting something that might be part of this Path3D branch
		params.exclude = [self.get_rid()]

		var hit := space.intersect_ray(params)
		if hit.size() > 0:
			var global_hit := hit["position"]
			var local_hit := global_transform.affine_inverse() * global_hit
			curve.set_point_position(i, local_hit)
