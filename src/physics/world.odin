package physics

import "core:math/rand"
import  rl "vendor:raylib"

MIN_BODY_SIZE  :: 0.01 * 0.01
MAX_BODY_SIZE :: 64 * 64

MIN_DENSITY :: 0.5  // g/cm^3
MAX_DENSITY :: 21.4 // Density of platinum

bodies: [dynamic]Body

init :: proc(size: int) {
    reserve(&bodies, size)

    for _ in 0..<size {
        append(&bodies, rand_body())
    }
}

deinit :: proc() {
    delete(bodies)
}

draw :: proc() {
    for body in bodies {
        switch shape in body.shape {
        case Circle:
            rl.DrawCircleV(body.pos, shape.radius, rl.BLUE)
        case Box:
            rl.DrawRectangleV(body.pos, shape.size, rl.ORANGE)
        }
    }

}

rand_body :: #force_inline proc() -> Body {
    pos := rl.Vector2{rand.float32() * 20, rand.float32() * 20}
    density := rand_f32(MIN_DENSITY, MAX_DENSITY)

    if rand.float32() < 0.5 {
        return new_circle(pos, rand_f32(1, 20), density)
    }

    w := rand_f32(1, 20)
    h := rand_f32(1, 20)
    return new_box(pos, {w, h}, density)
}

rand_f32 :: proc(lo, hi: f32) -> f32 {
    return lo + rand.float32() * (hi - lo)
}