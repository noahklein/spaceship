package main

import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

import "physics"
import "player"
import "ngui"

colors: [dynamic]rl.Color
timescale: f32

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

    camera := rl.Camera2D{ zoom = 4, offset = screen_size() / 2 }

    physics.init(40)
    defer physics.deinit()

    when ODIN_DEBUG {
        ngui.init()
        defer ngui.deinit()
    }

    // bg_texture := gen_star_bg_texture(1000, 1000)
    // bg_pos := rl.Vector2{-f32(bg_texture.width) / 2, -f32(bg_texture.height) / 2}

    rl.SetTargetFPS(120)

    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime() * timescale
        // cam_velocity := get_cam_movement()
        // camera.target += cam_velocity * dt

        player.update(dt)
        physics.update(dt, camera.offset/camera.zoom)

        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode2D(camera)
            // rl.DrawTextureV(bg_texture, bg_pos, rl.WHITE - {0, 0, 0, 100})
            physics.draw()
        rl.EndMode2D()

        when ODIN_DEBUG {
            rl.DrawFPS(rl.GetScreenWidth() - 80, 0)
            draw_gui(&camera)
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


gen_star_bg_texture :: proc(width, height: i32) -> rl.Texture {
    stars_img := rl.GenImageColor(width, height, rl.BLANK)
    defer rl.UnloadImage(stars_img)

    for x in 0..<stars_img.width do for y in 0..<stars_img.height {
        if rand.float32() < 0.999 do continue
        color := rand_color({190, 220, 220, 150}, rl.WHITE)
        rl.ImageDrawPixel(&stars_img, x, y, color)

        // Poor man's bloom.
        D :: 4 // bloom distance
        for i in -D..=D do for j in -D..=D {
            if i == 0 && j == 0 do continue

            x := x + i32(i)
            y := y + i32(j)
            if x < 0 || x >= stars_img.width ||
               y < 0 || y >= stars_img.height {
                continue
            }

            sqr_dist := i*i + j*j
            color := color
            color.a /= u8(sqr_dist)
            existing_color := rl.GetImageColor(stars_img, x, y)
            rl.ImageDrawPixel(&stars_img, x, y, add_colors(color, existing_color))
        }
    }

    return rl.LoadTextureFromImage(stars_img)
}

add_colors :: proc(a, b: rl.Color) -> rl.Color {
    a := linalg.array_cast(a, i32)
    b := linalg.array_cast(b, i32)

    c := linalg.clamp(a + b, 0, 255)
    return rl.Color(linalg.array_cast(c, u8))
}
