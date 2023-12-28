package physics

import "core:math/linalg"
import "core:math/rand"
import  rl "vendor:raylib"

MIN_BODY_SIZE  :: 0.01 * 0.01
MAX_BODY_SIZE :: 64 * 64

MIN_DENSITY :: 0.5  // g/cm^3; Density of water is 1
MAX_DENSITY :: 21.4 // Density of platinum

CELL_SIZE :: 1

FIXED_DT :: 1.0 / 120.0
dt_acc: f32

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
    delete(colors)

    for body in bodies {
        delete(body.vertices)
        delete(body.transformed)
    }
}

draw :: proc() {
    for &body, i in bodies {
        switch shape in body.shape {
        case Circle:
            rl.DrawCircleV(body.pos, shape.radius, colors[i])
            draw_circle_outline(body.pos, shape.radius, rl.WHITE)
        case Box:
            vs := body_get_vertices(&body)
            // Vertices are clockwise from top-left.
            rl.DrawTriangle(vs[0], vs[1], vs[2], colors[i])
            rl.DrawTriangle(vs[0], vs[2], vs[3], colors[i])
            rl.DrawLineV(vs[0], vs[1], rl.WHITE)
            rl.DrawLineV(vs[1], vs[2], rl.WHITE)
            rl.DrawLineV(vs[2], vs[3], rl.WHITE)
            rl.DrawLineV(vs[3], vs[0], rl.WHITE)
        }
    }
}

update :: proc(dt: f32, bounds: rl.Vector2) {
    dt_acc += dt
    for dt_acc >= FIXED_DT {
        dt_acc -= FIXED_DT
        fixed_update(FIXED_DT, bounds)
    }
}

fixed_update :: proc(dt: f32, bounds: rl.Vector2) {
    for &body in bodies {
        if body.vel     != 0 do move(&body, body.vel * dt)
        if body.rot_vel != 0 do rotate(&body, body.rot_vel * dt)

        if      body.pos.x < -bounds.x do body.pos.x =  bounds.x
        else if body.pos.x >  bounds.x do body.pos.x = -bounds.x
        if      body.pos.y < -bounds.y do body.pos.y =  bounds.y
        else if body.pos.y >  bounds.y do body.pos.y = -bounds.y

        rotate(&body, dt)
    }

    for &a_body, i in bodies[:len(bodies)-1] do for &b_body in bodies[i:] {
        hit := collision_check(a_body, b_body) or_continue

        a_body.vel -= hit.normal * hit.depth/2
        b_body.vel += hit.normal * hit.depth/2
    }
}

rand_body :: proc() -> Body {
    WIDTH  :: 200*CELL_SIZE
    HEIGHT :: 200*CELL_SIZE
    pos := rl.Vector2{
        random(0, WIDTH)  - WIDTH/2,
        random(0, HEIGHT) - HEIGHT/2,
    }
    density := random(MIN_DENSITY, MAX_DENSITY)

    if rand.float32() < 0.1 {
        return new_circle(pos, random(1, 5), density)
    }

    w := random(1, 10)
    h := random(1, 10)
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

draw_circle_outline :: proc(center: rl.Vector2, radius: f32, color: rl.Color) {
    rl.rlBegin(rl.RL_LINES)
    defer rl.rlEnd()

    rl.rlColor4ub(color.r, color.g, color.b, color.a)
    for i := f32(0); i < 360; i += 10 {
        rl.rlVertex2f(center.x + linalg.cos(i*rl.DEG2RAD) * radius, center.y + linalg.sin(i*rl.DEG2RAD) * radius)
        j := i + 10
        rl.rlVertex2f(center.x + linalg.cos(j*rl.DEG2RAD) * radius, center.y + linalg.sin(j*rl.DEG2RAD) * radius)
    }
}