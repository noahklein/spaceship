package physics

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

Hit :: struct {
    normal: rl.Vector2, // Points from a to b.
    depth: f32,
}

collision_check :: proc(a, b: ^Body) -> (Hit, bool) {
    switch as in a.shape {
    case Circle:
        switch bs in b.shape {
        case Circle: return collide_circles(a.pos, b.pos, as.radius, bs.radius)
        case Box: return {}, false
        }
    case Box:
        switch bs in b.shape {
        case Circle: return {}, false
        case Box:
            a_verts := body_get_vertices(a)
            b_verts := body_get_vertices(b)
            return intersect_polygons(a_verts, b_verts)
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

intersect_polygons :: proc(a, b: []rl.Vector2) -> (Hit, bool) {
    normal : rl.Vector2
    depth := f32(1e9)

    // Loop over every edge in polygon a.
    for v1, i in a {
        v2 := a[(i + 1) % len(a)]
        edge := v2 - v1

        axis := linalg.normalize(rl.Vector2{-edge.y, edge.x}) // Normal, negative reciprical slope trick.
        a_min, a_max := project_vertices(a, axis)
        b_min, b_max := project_vertices(b, axis)

        if a_min >= b_max || b_min >= a_max {
            return {}, false // There's a gap between the polygons on this axis.
        }

        axis_depth := min(b_max - a_min, a_max - b_min)
        if axis_depth < depth {
            depth  = axis_depth
            normal = axis
        }
    }

    // No gaps found yet, do the same for polygon b.
    for v1, i in b {
        v2 := b[(i + 1) % len(b)]
        edge := v2 - v1

        axis := linalg.normalize(rl.Vector2{-edge.y, edge.x})
        a_min, a_max := project_vertices(a, axis)
        b_min, b_max := project_vertices(b, axis)

        if a_min >= b_max || b_min >= a_max {
            return {}, false
        }

        axis_depth := min(b_max - a_min, a_max - b_min)
        if axis_depth < depth {
            depth  = axis_depth
            normal = axis
        }
    }

    a_center := polygon_center(a)
    b_center := polygon_center(b)
    if direction := b_center - a_center; linalg.dot(direction, normal) < 0 {
        normal = -normal
    }

    // No gaps found, polygons are colliding.
    return {
        depth = depth,
        normal = normal,
    }, true
}

project_vertices :: proc(verts: []rl.Vector2, axis: rl.Vector2) -> (low, high: f32) {
    low = 1e9
    high = -high

    for v in verts {
        projection := linalg.dot(v, axis)
        if projection < low  do low = projection
        if projection > high do high = projection
    }

    return
}

// A polygon's center is the arithmetic mean of the vertices.
polygon_center :: proc(verts: []rl.Vector2) -> (mean: rl.Vector2) {
    for v in verts do mean += v
    return mean / f32(len(verts))
}