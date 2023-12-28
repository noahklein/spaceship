package main

import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

import "physics"
import "ngui"

density : f32

main :: proc() {
       when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    defer free_all(context.temp_allocator)

    rl.SetTraceLogLevel(.ALL if ODIN_DEBUG else .WARNING)
    rl.InitWindow(1600, 900, "Terminalia")
    defer rl.CloseWindow()

    // Before we do anything, clear the screen to avoid transparent windows.
    rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
    rl.EndDrawing()

    camera := rl.Camera2D{ zoom = 1, offset = screen_size() / 2 }

    physics.init(20)
    defer physics.deinit()

    when ODIN_DEBUG {
        ngui.init()
        defer ngui.deinit()
    }


    bg_texture := gen_star_bg_texture()
    bg_pos := rl.Vector2{-f32(bg_texture.width) / 2, -f32(bg_texture.height) / 2}

    rl.SetTargetFPS(120)

    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime()
        cam_velocity := get_cam_movement()
        camera.target += cam_velocity * dt



        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode2D(camera)
            rl.DrawTextureV(bg_texture, bg_pos, rl.WHITE)
            physics.draw()
        rl.EndMode2D()

        when ODIN_DEBUG {
            rl.DrawFPS(rl.GetScreenWidth() - 80, 0)
            draw_gui(&camera)
        }
    }
}


draw_gui :: proc(camera: ^rl.Camera2D) {
    ngui.update()
    if ngui.begin_panel("Game", {0, 0, 400, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.1, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }
    }
}

screen_size :: #force_inline proc() -> rl.Vector2 {
    return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}

get_cam_movement :: proc() -> (dv: rl.Vector2) {
    SPEED :: 10
    if      rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do dv.x -= SPEED
    else if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do dv.x += SPEED
    if      rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do dv.y -= SPEED
    else if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do dv.y += SPEED
    return dv
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


gen_star_bg_texture :: proc() -> rl.Texture {
    stars_img := rl.GenImageColor(2500, 2500, rl.BLANK)
    defer rl.UnloadImage(stars_img)

    for x in 0..<stars_img.width do for y in 0..<stars_img.height {
        if rand.float32() < 0.999 do continue
        color := rand_color({220, 220, 220, 150}, rl.WHITE)
        rl.ImageDrawPixel(&stars_img, x, y, color)

        // Poor man's bloom.
        D :: 3 // bloom distance
        for i in -D..=D do for j in -D..=D {
            if i == 0 && j == 0 do continue

            x := x + i32(i)
            y := y + i32(j)

            sqr_dist := i*i + j*j
            color := color
            color.a /= u8(sqr_dist)
            rl.ImageDrawPixel(&stars_img, x, y, color)
        }
    }

    return rl.LoadTextureFromImage(stars_img)
}