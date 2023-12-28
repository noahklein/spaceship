package physics

import "core:fmt"
import rl "vendor:raylib"

Shape :: union { Circle, Box }

Circle :: struct { radius: f32 }
Box    :: struct { size: rl.Vector2 }

Body :: struct{
    pos, vel: rl.Vector2,
    rot, rot_vel: f32,

    is_static: bool,

    // @TODO: These properties should probably go in a constant lookup table, unless every
    // object needs different values.
    mass, density: f32,
    restitution: f32,
    shape: Shape,
}

new_circle :: proc(pos: rl.Vector2, radius, density: f32) -> Body {
    area := radius * radius * rl.PI
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Circle with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Circle with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)


    return {
        pos = pos,
        mass = area * density,
        density = density,
        restitution = 1,
        shape = Circle{ radius },
    }
}

new_box :: proc(pos: rl.Vector2, size: rl.Vector2, density: f32) -> Body {
    area := size.x * size.y
    fmt.assertf(MIN_BODY_SIZE <= area && area <= MAX_BODY_SIZE, "Box with invalid area: got %v, want in %v..=%v", area, MIN_BODY_SIZE, MAX_BODY_SIZE)
    fmt.assertf(MIN_DENSITY <= density && density <= MAX_DENSITY, "Box with invalid density: got %v, want in %v..=%v", density, MIN_DENSITY, MAX_DENSITY)

    return {
        pos = pos,
        density = density,
        mass = area * density,
        restitution = 1,
        shape = Box{ size },
    }
}