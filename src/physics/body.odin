package physics

import "core:fmt"
import rl "vendor:raylib"

Shape :: union { Circle, Polygon }

Circle  :: struct { radius: f32 }
Polygon :: struct {
    vertices, transformed: [dynamic]rl.Vector2,
    needs_transform_update: bool,
 }

BOX_TRIANGLE_INDICES :: [?]int{0, 1, 2, 0, 2, 3}

Body :: struct{
    pos, vel, force: rl.Vector2,
    rot, rot_vel: f32,

    is_static: bool,

    // @TODO: These properties should probably go in a constant lookup table, unless every
    // object needs different values.
    mass, inv_mass: f32,
    inv_rot_inertia: f32,
    restitution: f32,

    static_friction, dynamic_friction: f32,

    shape: Shape,
    aabb: rl.Rectangle,
}

new_circle :: proc(pos: rl.Vector2, radius, density: f32, is_static: bool) -> Body {
    area := radius * radius * rl.PI
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Circle with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Circle with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)

    mass := area*density
    rot_inertia := mass * radius*radius / 2

    return {
        pos = pos,

        is_static = is_static,
        mass = mass,
        inv_mass = 1 / mass if !is_static else 0,
        inv_rot_inertia = 1 / rot_inertia if !is_static else 0,

        static_friction = 0.6,
        dynamic_friction = 0.4,

        restitution = 1,
        shape = Circle{ radius },
    }
}

new_box :: proc(pos: rl.Vector2, size: rl.Vector2, density: f32, is_static: bool) -> (body: Body) {
    area := size.x * size.y
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Box with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Box with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)

    mass := area*density
    rot_inertia := mass * (size.x*size.x + size.y*size.y) / 12

    body = Body{
        pos = pos,
        is_static = is_static,
        mass = mass,
        inv_mass = 1 / mass if !is_static else 0,
        inv_rot_inertia = 1 / rot_inertia if !is_static else 0,

        static_friction = 0.6,
        dynamic_friction = 0.4,

        restitution = 1,
        shape = Polygon{ needs_transform_update = true },
    }
    polygon := &body.shape.(Polygon)
    box_vertices_init(polygon, size.x, size.y)
    resize(&polygon.transformed, 4)

    return body
}

@(private)
box_vertices_init :: proc(polygon: ^Polygon, width, height: f32) {
    left := -width / 2
    right := left + width
    bottom := -height / 2
    top := bottom + height

    reserve(&polygon.vertices, 4)
    append(&polygon.vertices,
        rl.Vector2{left, top},
        rl.Vector2{right, top},
        rl.Vector2{right, bottom},
        rl.Vector2{left, bottom},
    )
}

body_get_vertices :: proc(polygon: ^Polygon, pos: rl.Vector2, rot: f32) -> []rl.Vector2 {
    if polygon.needs_transform_update {
        polygon.needs_transform_update = false

        trans := transform_init(pos, rot)
        for &vtx, i in polygon.vertices  {
            #no_bounds_check polygon.transformed[i] = transform_apply(vtx, trans)
        }
    }

    return polygon.transformed[:]
}