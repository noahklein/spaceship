package physics

import "core:math/rand"
import  rl "vendor:raylib"

MIN_BODY_SIZE  :: 0.01 * 0.01
MAX_BODY_SIZE :: 64 * 64

MIN_DENSITY :: 0.5  // g/cm^3
MAX_DENSITY :: 21.4 // Density of platinum

CELL_SIZE :: 8

bodies: [dynamic]Body
colors: [dynamic]rl.Color

init :: proc(size: int) {
    reserve(&bodies, size)
    reserve(&colors, size)

    for _ in 0..<size {
        append(&bodies, rand_body())
        append(&colors, rand_color())
    }
}

deinit :: proc() {
    delete(bodies)
}

draw :: proc() {
    for body, i in bodies {
        switch shape in body.shape {
        case Circle:
            rl.DrawCircleV(body.pos, shape.radius, colors[i])
        case Box:
            rl.DrawRectangleV(body.pos, shape.size, colors[i])
        }
    }
}

rand_body :: proc() -> Body {
    WIDTH  :: 60*CELL_SIZE
    HEIGHT :: 30*CELL_SIZE
    pos := rl.Vector2{
        random(0, WIDTH)  - WIDTH/2,
        random(0, HEIGHT) - HEIGHT/2,
    }
    density := random(MIN_DENSITY, MAX_DENSITY)

    if rand.float32() < 0.5 {
        return new_circle(pos, random(5, 20), density)
    }

    w := random(5, 40)
    h := random(5, 40)
    return new_box(pos, {w, h}, density)
}

rand_color :: proc(low := rl.BLACK, high := rl.WHITE) -> rl.Color {
    rand_u8 :: proc(low, high: u8) -> u8 {
        if low == high do return low

        r := rand.int_max(int(high - low))
        return u8(r) + low
    }

    return {
        rand_u8(low.r, high.r),
        rand_u8(low.g, high.g),
        rand_u8(low.b, high.b),
        rand_u8(low.a, high.a),
    }
}

random :: proc(lo, hi: f32) -> f32 {
    return lo + rand.float32() * (hi - lo)
}