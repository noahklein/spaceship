package physics

import "core:fmt"
import rl "vendor:raylib"

Shape :: union { Circle, Box }

Circle :: struct { radius: f32 }
Box    :: struct { size: rl.Vector2 }

BOX_TRIANGLE_INDICES :: [?]int{0, 1, 2, 0, 2, 3}

Body :: struct{
    pos, vel, force: rl.Vector2,
    rot, rot_vel: f32,

    is_static: bool,

    // @TODO: These properties should probably go in a constant lookup table, unless every
    // object needs different values.
    mass, inv_mass, density: f32,
    restitution: f32,
    shape: Shape,

    vertices:    [dynamic]rl.Vector2, // Circles have no vertices.
    transformed: [dynamic]rl.Vector2,
    needs_transform_update: bool,
}

new_circle :: proc(pos: rl.Vector2, radius, density: f32, is_static: bool) -> Body {
    area := radius * radius * rl.PI
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Circle with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Circle with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)


    return {
        pos = pos,
        is_static = is_static,
        mass = area*density,
        inv_mass = 1 / (area*density) if !is_static else 0,

        density = density,
        restitution = 1,
        shape = Circle{ radius },
    }
}

new_box :: proc(pos: rl.Vector2, size: rl.Vector2, density: f32, is_static: bool) -> (body: Body) {
    area := size.x * size.y
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Box with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Box with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)

    body = Body{
        pos = pos,
        is_static = is_static,
        mass = area * density,
        inv_mass = 1 / (area*density) if !is_static else 0,

        density = density,
        restitution = 1,
        shape = Box{ size },
        needs_transform_update =  true,
    }
    box_vertices_init(&body, size.x, size.y)
    resize(&body.transformed, 4)

    return body
}

box_vertices_init :: proc(body: ^Body, width, height: f32) {
    left := -width / 2
    right := left + width
    bottom := -height / 2
    top := bottom + height

    reserve(&body.vertices, 4)
    append(&body.vertices, rl.Vector2{left,  top})
    append(&body.vertices, rl.Vector2{right, top})
    append(&body.vertices, rl.Vector2{right, bottom})
    append(&body.vertices, rl.Vector2{left,  bottom})
}

body_get_vertices :: proc(body: ^Body) -> []rl.Vector2 {
    if body.needs_transform_update {
        body.needs_transform_update = false

        trans := transform_init(body.pos, body.rot)
        for &vtx, i in body.vertices {
            body.transformed[i] = transform_apply(vtx, trans)
        }
    }

    return body.transformed[:]
}