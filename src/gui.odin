package main

import rl "vendor:raylib"

import "ngui"
import "physics"

draw_gui :: proc(camera: ^rl.Camera2D) {
    ngui.update()
    if ngui.begin_panel("Game", {0, 0, 400, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.1, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }

        if ngui.flex_row({0.2, 0.3, 0.3, 0.2}) {
            ngui.text("Player")
            player := &physics.bodies[0]
            ngui.vec2(&player.pos, label = "Position")
            ngui.arrow(&player.vel, "Velocity")
            ngui.float(&player.rot_vel, label = "Rot Vel")
        }

        if ngui.flex_row({0.25, 0.25, 0.25}) {
            ngui.slider(&timescale, 0, 10, label = "Timescale")
            if ngui.button("Play" if timescale == 0 else "Pause") || rl.IsKeyPressed(.SPACE) {
                timescale = 1 if timescale == 0 else 0
            }
            ngui.slider(&physics.FRICTION, 0, 0.3, label = "Friction")
        }
    }
}

