package physics

import "core:math/linalg"
import rl "vendor:raylib"

Hit :: struct {
    normal: rl.Vector2, // Points from a to b.
    depth: f32,
}

collision_check :: proc(a, b: Body) -> (Hit, bool) {
    switch as in a.shape {
    case Circle:
        switch bs in b.shape {
        case Circle: return collide_circles(a.pos, b.pos, as.radius, bs.radius)
        case Box: return {}, false
        }
    case Box:
        switch bs in b.shape {
        case Circle: return {}, false
        case Box: return {}, false
        }
    }

    panic("Impossible: unsupported shape in collision_check")
}

collide_circles :: proc(a_center, b_center: rl.Vector2, a_radius, b_radius: f32) -> (Hit, bool) {
    dist := linalg.distance(a_center, b_center)

    radii := a_radius + b_radius
    if dist >= radii do return {}, false

    return {
        normal = b_center - a_center,
        depth = radii - dist,
    }, true
}