package rlutil

import rl "vendor:raylib"

DrawPolygonLines :: proc(vertices: []rl.Vector2, color: rl.Color) {
    for v1, i in vertices {
        v2 := vertices[(i+1) % len(vertices)]

        rl.DrawLineV(v1, v2, color)
    }
}