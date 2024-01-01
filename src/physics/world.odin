package physics

import "core:math/linalg"
import "core:math/rand"
import  rl "vendor:raylib"

import "../rlutil"

MIN_BODY_SIZE  :: 0.01 * 0.01
MAX_BODY_SIZE :: 64 * 64 * 10

MIN_DENSITY :: 0.5  // g/cm^3; Density of water is 1
MAX_DENSITY :: 21.4 // Density of platinum

CELL_SIZE :: 1
MAX_SPEED :: 64

FRICTION: f32 = 0.01
GRAVITY := rl.Vector2{0, 9.8}

FIXED_DT :: 1.0 / 240.0
dt_acc: f32

bodies:  [dynamic]Body
colors:  [dynamic]rl.Color

collision_pairs : [dynamic][2]int // Broad-phase
contacts: [dynamic]Manifold

init :: proc(size: int, bounds: rl.Vector2) {
    reserve(&bodies, size)
    reserve(&colors, size)
    reserve(&contacts, size)
    reserve(&collision_pairs, size)

    player_body := new_circle(0, 2, 1, false)
    append_body(player_body, rl.WHITE)

    floor_body := new_box({0,  0.8*bounds.y}, {2 * bounds.x, 0.2*bounds.y}, 1, true)
    append_body(floor_body, rl.GREEN)

    slant_right := new_box({-100, -10}, {bounds.x, 0.2*bounds.y}, 1, true)
    rotate(&slant_right, 20*rl.DEG2RAD)
    append_body(slant_right, rl.GREEN)

    slant_left := new_box({110, -15}, {bounds.x, 0.2*bounds.y}, 1, true)
    rotate(&slant_left, -20*rl.DEG2RAD)
    append_body(slant_left, rl.GREEN)
}

deinit :: proc() {
    delete(bodies)
    delete(colors)
    delete(contacts)
    delete(collision_pairs)

    for body in bodies {
        delete(body.vertices)
        delete(body.transformed)
    }
}

draw :: proc(debug: bool) {
    for &body, i in bodies {
        color := colors[i]

        switch shape in body.shape {
        case Circle:
            rl.DrawCircleV(body.pos, shape.radius, color)
            draw_circle_outline(body.pos, shape.radius, rl.WHITE)

            va : rl.Vector2
            vb : rl.Vector2 = {shape.radius, 0}
            t := transform_init(body.pos, body.rot)
            va = transform_apply(va, t)
            vb = transform_apply(vb, t)
            rl.DrawLineV(va, vb, rl.WHITE)
        case Box:
            vs := body_get_vertices(&body)
            // Vertices are clockwise from top-left.
            rl.DrawTriangle(vs[0], vs[1], vs[2], color)
            rl.DrawTriangle(vs[0], vs[2], vs[3], color)

            rlutil.DrawPolygonLines(vs, rl.WHITE)
        }

        if debug {
            // rl.DrawRectangleLinesEx(body.aabb, 1, rl.LIME)

            for hit in contacts {
                switch hit.contact_count {
                    case 0: continue
                    case 1: rl.DrawCircleV(hit.contact1, 1, rl.WHITE)
                    case 2:
                        rl.DrawCircleV(hit.contact1, 1, rl.WHITE)
                        rl.DrawCircleV(hit.contact2, 1, rl.PINK)
                }
            }
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

@(private)
fixed_update :: proc(dt: f32, bounds: rl.Vector2) {
    for &body in bodies {
        body.force += GRAVITY * body.mass
        accel := body.force * body.inv_mass
        body.vel += accel * dt
        body.vel *= 1 - FRICTION * FRICTION
        defer body.force = 0

        if length := linalg.length(body.vel); length > MAX_SPEED {
            body.vel = linalg.normalize(body.vel) * MAX_SPEED
        }

        if body.vel     != 0 do move(&body, body.vel * dt)
        if body.rot_vel != 0 do rotate(&body, body.rot_vel * dt)

        if      body.pos.x < -bounds.x do body.pos.x =  bounds.x
        else if body.pos.x >  bounds.x do body.pos.x = -bounds.x
        if      body.pos.y < -bounds.y do body.pos.y =  bounds.y
        else if body.pos.y >  bounds.y do body.pos.y = -bounds.y
    }

    // Update AABBs for broad-phase collision.
    for &b in bodies do b.aabb = get_aabb(&b)

    // Broad-phase collision detection.
    clear(&collision_pairs)
    for i in 0..<len(bodies)-1 do for j in i+1..<len(bodies) {
        // Broad-phase checks to early-exit.
        a_body, b_body := bodies[i], bodies[j]
        if a_body.is_static && b_body.is_static do continue
        if !rl.CheckCollisionRecs(a_body.aabb, b_body.aabb) do continue

        append(&collision_pairs, [2]int{i, j})
    }

    // Narrow-phase collision detection.
    clear(&contacts)
    for pair in collision_pairs {
        a_body, b_body := &bodies[pair.x], &bodies[pair.y]
        // Actually check collision for real.
        hit := collision_check(a_body, b_body) or_continue

        // Move bodies to resolve collision; static bodies never move.
        if      a_body.is_static do move(b_body, hit.normal*hit.depth)
        else if b_body.is_static do move(a_body, -hit.normal*hit.depth)
        else {
            move(a_body, -hit.normal*hit.depth / 2)
            move(b_body,  hit.normal*hit.depth / 2)
        }

        cp1, cp2, count := find_contact_points(a_body, b_body)
        append(&contacts, Manifold{
            a_body = a_body, b_body = b_body,
            normal = hit.normal,
            depth = hit.depth,
            contact1 = cp1,
            contact2 = cp2,
            contact_count = count,
        })
    }

    // Collision resolution.
    for hit in contacts {
        resolve_collision(hit)
    }
}

// This function is a big mess to avoid recalculating certain things.
resolve_collision :: proc(hit: Manifold) {
    a, b := hit.a_body, hit.b_body
    e := min(a.restitution, b.restitution) // Elasticity

    contacts := [2]rl.Vector2{hit.contact1, hit.contact2}

    // Cached values for future steps. Written to by first loop.
    ra_list, rb_list, impulses: [2]rl.Vector2
    j_list: [2]f32

    // For each contact point get linear and angular impulses to apply to colliding bodies.
    for i in 0..<hit.contact_count {
        ra := contacts[i] - a.pos
        rb := contacts[i] - b.pos

        // Save these for the resolution and friction loops.
        ra_list[i] = ra
        rb_list[i] = rb

        ra_perp := rl.Vector2{-ra.y, ra.x}
        rb_perp := rl.Vector2{-rb.y, rb.x}

        // Angular linear velocities.
        a_ang_lin_vel := ra_perp * a.rot_vel
        b_ang_lin_vel := rb_perp * b.rot_vel

        rel_vel := (b.vel + b_ang_lin_vel) - (a.vel + a_ang_lin_vel)
        contact_vel_mag := linalg.dot(rel_vel, hit.normal)
        if contact_vel_mag > 0 {
            continue
        }

        ra_perp_dot_n := linalg.dot(ra_perp, hit.normal)
        rb_perp_dot_n := linalg.dot(rb_perp, hit.normal)

        // Impulse
        j := -(1 + e) * contact_vel_mag
        j /= a.inv_mass + b.inv_mass +
            (ra_perp_dot_n * ra_perp_dot_n) * a.inv_rot_inertia +
            (rb_perp_dot_n * rb_perp_dot_n) * b.inv_rot_inertia

        j /= f32(hit.contact_count) // Distribute force evenly amongst contacts.

        j_list[i] = j // Retained for friction loop.
        impulses[i] = j * hit.normal // Don't apply impulses until all have been calculated.
    }

    // Apply impulses to bodies.
    for i in 0..<hit.contact_count {
        impulse := impulses[i]

        a.vel -= impulse * a.inv_mass
        b.vel += impulse * b.inv_mass

        a.rot_vel -= linalg.cross(ra_list[i], impulse) * a.inv_rot_inertia
        b.rot_vel += linalg.cross(rb_list[i], impulse) * b.inv_rot_inertia
    }

    // =========
    // Friction
    s_fric :=  (a.static_friction + b.static_friction) / 2
    d_fric := (a.dynamic_friction + b.static_friction) / 2

    // Same thing again, for each contact point calcualte friction impulses.
    friction_impulses: [2]rl.Vector2
    for i in 0..<hit.contact_count {
        ra, rb := ra_list[i], rb_list[i]
        ra_perp := rl.Vector2{-ra.y, ra.x}
        rb_perp := rl.Vector2{-rb.y, rb.x}

        // Angular linear velocities.
        a_ang_lin_vel := ra_perp * a.rot_vel
        b_ang_lin_vel := rb_perp * b.rot_vel

        rel_vel := (b.vel + b_ang_lin_vel) - (a.vel + a_ang_lin_vel)
        tangent := rel_vel - linalg.dot(rel_vel, hit.normal) * hit.normal
        if rlutil.nearly_eq_vector(tangent, 0) do continue
        tangent = linalg.normalize(tangent)

        ra_perp_dot_t := linalg.dot(ra_perp, tangent)
        rb_perp_dot_t := linalg.dot(rb_perp, tangent)

        // Friction impulse
        jt := -linalg.dot(rel_vel, tangent)
        jt /= a.inv_mass + b.inv_mass +
            (ra_perp_dot_t * ra_perp_dot_t) * a.inv_rot_inertia +
            (rb_perp_dot_t * rb_perp_dot_t) * b.inv_rot_inertia

        jt /= f32(hit.contact_count) // Distribute force evenly amongst contacts.

        j := j_list[i]

        // Coulomb's law
        if abs(jt) <= j*s_fric {
            friction_impulses[i] = jt * tangent
        } else {
            friction_impulses[i] = -j * tangent * d_fric
        }
    }

    // Apply friction to bodies.
    for i in 0..<hit.contact_count {
        impulse := friction_impulses[i]

        a.vel -= impulse * a.inv_mass
        b.vel += impulse * b.inv_mass

        a.rot_vel -= linalg.cross(ra_list[i], impulse) * a.inv_rot_inertia
        b.rot_vel += linalg.cross(rb_list[i], impulse) * b.inv_rot_inertia
    }
}

append_body :: #force_inline proc(body: Body, color: rl.Color) {
    append(&bodies, body)
    append(&colors, color)
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