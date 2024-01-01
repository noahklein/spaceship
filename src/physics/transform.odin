package physics

import "core:math/linalg"
import rl "vendor:raylib"

Transform :: struct {
    pos: rl.Vector2,
    sin, cos: f32,
}

transform_init :: #force_inline proc(pos: rl.Vector2, angle: f32) -> Transform {
    return {
        pos = pos,
        sin = linalg.sin(angle),
        cos = linalg.cos(angle),
    }
}

transform_apply :: #force_inline proc(v: rl.Vector2, t: Transform) -> rl.Vector2 {
    return {
        t.pos.x + t.cos*v.x - t.sin*v.y,
        t.pos.y + t.sin*v.x + t.cos*v.y,
    }
}

move_to :: #force_inline proc(body: ^Body, pos: rl.Vector2) {
    body.pos = pos
    set_needs_transform(body)
}

move :: #force_inline proc(body: ^Body, delta: rl.Vector2) {
    body.pos += delta
    set_needs_transform(body)
}

rotate :: #force_inline proc(body: ^Body, angle: f32) {
    body.rot += angle
    set_needs_transform(body)
}

@(private="file")
set_needs_transform :: #force_inline proc(body: ^Body) {
    if polygon, ok := &body.shape.(Polygon); ok {
        polygon.needs_transform_update = true
    }
}