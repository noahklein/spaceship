package physics

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import  rl "vendor:raylib"

MIN_BODY_SIZE  :: 0.01 * 0.01
MAX_BODY_SIZE :: 64 * 64

MIN_DENSITY :: 0.5  // g/cm^3; Density of water is 1
MAX_DENSITY :: 21.4 // Density of platinum

CELL_SIZE :: 1
MAX_SPEED :: 64

FRICTION: f32 = 0.01
GRAVITY := rl.Vector2{0, -9.8}

FIXED_DT :: 1.0 / 120.0
dt_acc: f32

bodies:  [dynamic]Body
colors:  [dynamic]rl.Color
borders: [dynamic]rl.Color

init :: proc(size: int) {
    reserve(&bodies, size)
    reserve(&colors, size)

    for i in 0..<size {
        body := rand_body()
        for i == 0 && body.inv_mass == 0 do body = rand_body()
        append(&bodies, body)
        append(&colors, rand_color(rl.GREEN, rl.BLUE) if !body.is_static else rl.RED)
        append(&borders, rl.WHITE if !body.is_static else rl.YELLOW)
    }
}

deinit :: proc() {
    delete(bodies)
    delete(colors)
    delete(borders)

    for body in bodies {
        delete(body.vertices)
        delete(body.transformed)
    }
}

draw :: proc() {
    for &body, i in bodies {
        color := colors[i]
        border_color := borders[i]

        switch shape in body.shape {
        case Circle:
            rl.DrawCircleV(body.pos, shape.radius, color)
            draw_circle_outline(body.pos, shape.radius, border_color)
        case Box:
            vs := body_get_vertices(&body)
            // Vertices are clockwise from top-left.
            rl.DrawTriangle(vs[0], vs[1], vs[2], color)
            rl.DrawTriangle(vs[0], vs[2], vs[3], color)
            rl.DrawLineV(vs[0], vs[1], border_color)
            rl.DrawLineV(vs[1], vs[2], border_color)
            rl.DrawLineV(vs[2], vs[3], border_color)
            rl.DrawLineV(vs[3], vs[0], border_color)
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
        accel := body.force * body.inv_mass
        body.vel += accel * dt
        defer body.force = 0

        if length := linalg.length(body.vel); length > MAX_SPEED {
            body.vel = linalg.normalize(body.vel) * MAX_SPEED
        }

        if body.vel     != 0 do move(&body, body.vel * dt)
        if body.rot_vel != 0 do rotate(&body, body.rot_vel * dt)

        body.vel -= body.vel * FRICTION * dt

        if      body.pos.x < -bounds.x do body.pos.x =  bounds.x
        else if body.pos.x >  bounds.x do body.pos.x = -bounds.x
        if      body.pos.y < -bounds.y do body.pos.y =  bounds.y
        else if body.pos.y >  bounds.y do body.pos.y = -bounds.y
    }

    for &a_body, i in bodies[:len(bodies)-1] do for &b_body in bodies[i+1:] {
        hit := collision_check(&a_body, &b_body) or_continue

        if a_body.is_static && b_body.is_static do continue
        else if a_body.is_static do move(&b_body, hit.normal*hit.depth)
        else if b_body.is_static do move(&a_body, -hit.normal*hit.depth)
        else {
            move(&a_body, -hit.normal*hit.depth / 2)
            move(&b_body,  hit.normal*hit.depth / 2)
        }

        e := min(a_body.restitution, b_body.restitution) // Elasticity
        rel_vel := (b_body.vel - a_body.vel)
        j := -(1 + e) * linalg.dot(rel_vel, hit.normal)
        j /= a_body.inv_mass + b_body.inv_mass

        a_body.vel -= j * a_body.inv_mass * hit.normal
        b_body.vel += j * b_body.inv_mass * hit.normal
    }
}

rand_body :: proc() -> Body {
    WIDTH  :: 200*CELL_SIZE
    HEIGHT :: 200*CELL_SIZE
    pos := rl.Vector2{
        random(0, WIDTH)  - WIDTH/2,
        random(0, HEIGHT) - HEIGHT/2,
    }
    density := f32(1)
    is_static := rand.float32() < 0.5

    if rand.float32() < 0.5 {
        return new_circle(pos, random(2, 5), density, is_static)
    }

    w := random(2, 10)
    h := random(2, 10)
    return new_box(pos, {w, h}, density, is_static)
}

rand_color :: proc(low := rl.BLACK, high := rl.WHITE) -> rl.Color {
    rand_u8 :: proc(low, high: u8) -> u8 {
        low, high := low, high
        if low == high do return low
        if low > high do low, high = high, low

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