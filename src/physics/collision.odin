package physics

import "core:math/linalg"
import rl "vendor:raylib"

Hit :: struct {
    normal: rl.Vector2, // Points from a to b.
    depth: f32,
}

collision_check :: proc(a, b: ^Body) -> (Hit, bool) {
    // Broad-phase check to early exit.
    if !rl.CheckCollisionRecs(a.aabb, b.aabb) {
        return {}, false
    }

    switch as in a.shape {
    case Circle:
        switch bs in b.shape {
        case Circle: return collide_circles(a.pos, b.pos, as.radius, bs.radius)
        case Box:
            verts := body_get_vertices(b)
            hit, ok := collide_polygon_circle(verts, b.pos, a.pos, as.radius)
            hit.normal = -hit.normal
            return hit, ok

        }
    case Box:
        switch bs in b.shape {
        case Circle:
            verts := body_get_vertices(a)
            hit, ok := collide_polygon_circle(verts, a.pos, b.pos, bs.radius)
            // hit.normal = -hit.normal
            return hit, ok

        case Box:
            a_verts := body_get_vertices(a)
            b_verts := body_get_vertices(b)
            return collide_polygons(a_verts, b_verts, a.pos, b.pos)
        }
    }

    panic("Impossible: unsupported shape in collision_check")
}

collide_circles :: proc(a_center, b_center: rl.Vector2, a_radius, b_radius: f32) -> (Hit, bool) {
    dist := linalg.distance(a_center, b_center)

    radii := a_radius + b_radius
    if dist >= radii do return {}, false

    return {
        normal = linalg.normalize(b_center - a_center),
        depth = radii - dist,
    }, true
}

collide_polygon_circle :: proc(poly: []rl.Vector2, poly_center, center: rl.Vector2, radius: f32) -> (Hit, bool) {
    normal : rl.Vector2
    depth := f32(1e18)

    // Loop over every edge in polygon.
    for v1, i in poly {
        v2 := poly[(i + 1) % len(poly)]
        edge := v2 - v1

        axis := linalg.normalize(rl.Vector2{-edge.y, edge.x}) // Normal, negative reciprical slope trick.
        a_min, a_max := project_vertices(poly, axis)
        b_min, b_max := project_circle(center, radius, axis)

        if a_min >= b_max || b_min >= a_max {
            return {}, false // There's a gap between the polygons on this axis.
        }

        axis_depth := min(b_max - a_min, a_max - b_min)
        if axis_depth < depth {
            depth  = axis_depth
            normal = axis
        }
    }

    cp := polygon_closest_point(center, poly)
    axis := linalg.normalize(cp - center)
    a_min, a_max := project_vertices(poly, axis)
    b_min, b_max := project_circle(center, radius, axis)
    if a_min >= b_max || b_min >= b_max {
        return {}, false
    }

    axis_depth := min(b_max - a_min, a_max - b_min)
    if axis_depth < depth {
        depth = axis_depth
        normal = axis
    }

    if direction := center - poly_center; linalg.dot(direction, normal) < 0 {
        normal = -normal
    }

    return {depth = depth, normal = normal}, true

}


collide_polygons :: proc(a, b: []rl.Vector2, a_center, b_center: rl.Vector2) -> (hit: Hit, ok: bool) {
    a_hit := _collide_polygons(a, b, a_center, b_center) or_return
    b_hit := _collide_polygons(b, a, b_center, a_center) or_return

    if a_hit.depth < b_hit.depth {
        return a_hit, true
    }

    b_hit.normal = -b_hit.normal
    return b_hit, true
}

@(private)
_collide_polygons :: proc(a, b: []rl.Vector2, a_center, b_center: rl.Vector2) -> (Hit, bool) {
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
    low = 1e18
    high = -high

    for v in verts {
        projection := linalg.dot(v, axis)
        if projection < low  do low = projection
        if projection > high do high = projection
    }

    return
}

project_circle :: proc(center: rl.Vector2, radius: f32, axis: rl.Vector2) -> (low, high: f32) {
    dir := axis * radius
    low  = linalg.dot(center - dir, axis)
    high = linalg.dot(center + dir, axis)

    return min(low, high), max(low, high)
}

// Axis-aligned bounding box, for fast broad-phase filtering.
get_aabb :: proc(b: Body) -> rl.Rectangle {
    rmin: rl.Vector2 = 1e9
    rmax: rl.Vector2 = -1e9
    switch s in b.shape {
        case Circle:
            rmin = b.pos - s.radius
            rmax = b.pos + s.radius
        case Box:
            for v in b.transformed {
                rmin = linalg.min(rmin, v)
                rmax = linalg.max(rmax, v)
            }
    }

    return {rmin.x, rmin.y, rmax.x - rmin.x, rmax.y - rmin.y}
}

// A polygon's center is the arithmetic mean of the vertices.
polygon_center :: #force_inline proc(verts: []rl.Vector2) -> (mean: rl.Vector2) {
    for v in verts do mean += v
    return mean / f32(len(verts))
}

// Closest vertex on a polygon to a circle.
polygon_closest_point :: #force_inline proc(circle_center: rl.Vector2, verts: []rl.Vector2) -> (cp: rl.Vector2) {
    min_dist := f32(1e18)
    for v in verts {
        dist := linalg.distance(v, circle_center)
        if dist < min_dist {
            min_dist = dist
            cp = v
        }
    }

    return
}