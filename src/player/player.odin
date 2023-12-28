package player

import "core:math/linalg"
import rl "vendor:raylib"
import "../ngui"
import "../physics"


SPEED :: 16 * 16

update :: proc(dt: f32) {
    delta_vel := input()
    if delta_vel == 0 {
        physics.bodies[0].vel -= physics.bodies[0].vel * 0.1 * dt
        return
    }

    delta_vel = linalg.normalize(delta_vel)
    physics.bodies[0].force += delta_vel * SPEED
}

input :: proc() -> (dv: rl.Vector2) {
    if ngui.want_keyboard() do return 0

    if      rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do dv.x = -1
    else if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do dv.x =  1
    if      rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do dv.y = -1
    else if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do dv.y =  1

    return dv
}