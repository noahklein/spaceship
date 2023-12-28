package ngui

import "core:math/linalg"
import "core:fmt"
import "core:strings"
import "core:intrinsics"
import rl "vendor:raylib"

INF :: f32(1e7)

state : NGui

NGui :: struct {
    mouse: rl.Vector2, // Mouse position

    dragging: cstring,
    drag_offset: rl.Vector2,

    button_pressed: cstring,

    text_inputs: map[cstring]TextInput,
    active_input: cstring,
    last_keypress_time: f64,

    panels: map[cstring]Panel,
    panel: cstring, // Active panel
    hovered_panel: cstring,
    panel_row, panel_column: int,
    column_widths: []f32,
}

init :: proc() {
}

deinit :: proc() {
    delete(state.panels)
    for _, &ti in state.text_inputs {
        strings.builder_destroy(&ti.buf)
    }
    delete(state.text_inputs)
}

update :: proc() {
    screen := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    state.mouse = linalg.clamp(rl.GetMousePosition(), 0, screen)
    state.hovered_panel = nil

    if state.dragging != nil && rl.IsMouseButtonUp(.LEFT) {
        state.dragging = nil
    }

    if p, ok := &state.panels[state.dragging]; ok {
        pos := state.mouse + state.drag_offset
        p.rect.x = pos.x
        p.rect.y = pos.y
    }

    assert(len(state.panels) <= 32, "Using more than 32 panels, is this intentional?")
    assert(len(state.text_inputs) <= 32, "Using more than 32 text inputs, is this intentional?")
}

slider :: proc(val: ^f32, $low, $high: f32, label: cstring) {
    rect := flex_rect()
    slider_rect(rect, val, low, high, label)
}

slider_rect :: proc(rect: rl.Rectangle, val: ^f32, $low, $high: f32, label: cstring) {
    #assert(low < high)
    label_rect, body_rect := label_split_rect(rect, label)

    hover := hovered(body_rect)
    key := fmt.ctprintf("slider#%v", label)

    if hover && rl.IsMouseButtonPressed(.LEFT) {
        state.dragging = key
    }

    active := state.dragging == key
    if active {
        mouse_x := clamp(state.mouse.x, body_rect.x, body_rect.x + body_rect.width)
        pct := (mouse_x - body_rect.x) / body_rect.width
        val^ = linalg.lerp(low, high, pct)
    }

    text_rect(label_rect, label)
    rl.DrawRectangleRec(body_rect, dark_color(hover, active))

    x := clamp(val^, low, high)
    pct := (x - low) / (high - low)
    x = linalg.lerp(body_rect.x, body_rect.x + body_rect.width - SLIDER_WIDTH, pct)
    handle_rect := rl.Rectangle{x, body_rect.y, SLIDER_WIDTH, body_rect.height}
    rl.DrawRectangleRec(handle_rect, button_color(hover, active))
}

button :: proc(label: cstring) -> bool {
    rect := flex_rect()
    return button_rect(rect, label)
}

button_rect :: proc(rect: rl.Rectangle, label: cstring) -> bool {
    hover := hovered(rect)
    key := fmt.ctprintf("%s#button#%s", state.panel, label)
    active := state.button_pressed == key
    if hover && rl.IsMouseButtonPressed(.LEFT) {
        state.button_pressed = key
        active = true
    }

    // Draw button
    color := button_color(hover, active, hover && rl.IsMouseButtonDown(.LEFT))
    rl.DrawRectangleRec(rect, color)
    text_rect(rect, label, color = rl.WHITE, align = .Center)

    // Button is only pressed if the user pressed down AND released in the rect.
    release := active && rl.IsMouseButtonReleased(.LEFT)
    if release do state.button_pressed = nil

    return release && hover
}

vec2 :: proc(v: ^rl.Vector2, min: f32 = -INF, max: f32 = INF, step: f32 = 0.1, label: cstring = nil) {
    rect := flex_rect()
    rect.width /= 2

    first := rect
    float_rect(first, &v.x, min, max, step, label)

    second := rect
    second.x += rect.width
    second_label: cstring = " " if label != nil else nil // empty label to pad height.
    float_rect(second, &v.y, min, max, step, second_label)

    divider := second
    if label != nil {
        _, divider = label_split_rect(second, label)
    }
    div_padding := divider.height / 4
    rl.DrawLineEx({divider.x, divider.y + div_padding}, {divider.x, divider.y + divider.height - div_padding}, 1, TEXT_COLOR)
}

float :: proc(f: ^f32, min := -INF, max := INF, step: f32 = 0.1, label: cstring = nil) {
    rect := flex_rect()
    float_rect(rect, f, min = min, max = max, step = step, label = label)
}

// Draggable f32 editor. Hold alt while dragging for finer control, hold shift to speed it up.
float_rect :: proc(rect: rl.Rectangle, f: ^f32, min := -INF, max := INF, step: f32 = 0.1, label: cstring = nil) {
    label_box, float_box := label_split_rect(rect, label)

    key := fmt.ctprintf("f32#%v", rect)
    press := pressed(rect)
    if press {
        state.dragging = key
        state.drag_offset = rl.Vector2{rect.x, rect.y} - state.mouse
    }
    dragging := state.dragging == key
    if dragging {
        slow_down: f32 = 0.1 if rl.IsKeyDown(.LEFT_ALT)   else 1.0
        speed_up : f32 = 10  if rl.IsKeyDown(.LEFT_SHIFT) else 1.0
        f^ += rl.GetMouseDelta().x * step * slow_down * speed_up
        f^ = clamp(f^, min, max)
    }


    rl.DrawRectangleRec(float_box, button_color(hovered(rect), dragging, press))
    text_rect(float_box, fmt.ctprintf("%.2f", f^), color = rl.WHITE, align = .Center)
    if label != nil {
        text_rect(label_box, label)
    }
}

radio_group :: proc($Enum: typeid, val: ^Enum, label: cstring = nil) {
    rect := flex_rect()
    radio_group_rect(rect, Enum, val, label)
}

radio_group_rect :: proc(rect: rl.Rectangle, $Enum: typeid, val: ^Enum, label: cstring = nil)
                        where intrinsics.type_is_enum(Enum) && len(Enum) > 0 {
    label_rect, btn_rect := label_split_rect(rect, label)

    btn_rect.width /= f32(len(Enum))
    for field in Enum {
        cstr := fmt.ctprintf("%v", field)
        if toggle_rect(btn_rect, cstr, val^ == field) {
            val^ = field
        }

        btn_rect.x += btn_rect.width
    }

    if label != nil {
        text_rect(label_rect, label)
    }
}

flags :: proc(bs: ^$B/bit_set[$Enum], label: cstring = nil) {
    rect := flex_rect()
    flags_rect(rect, bs, label)
}

flags_rect :: proc(rect: rl.Rectangle, bs: ^$B/bit_set[$Enum], label: cstring = nil)
                where intrinsics.type_is_enum(Enum) && len(Enum) > 0 {
    label_rect, btn_rect := label_split_rect(rect, label)

    btn_rect.width /= f32(len(Enum))
    for field in Enum {
        cstr := fmt.ctprintf("%v", field)
        enabled := field in bs
        if toggle_rect(btn_rect, cstr, enabled) {
            if enabled {
                bs^ -= {field}
            } else {
                bs^ += {field}
            }

        }
        btn_rect.x += btn_rect.width
    }

    if label != nil {
        text_rect(label_rect, label)
    }
}

toggle :: proc(label: cstring, selected: bool) -> bool {
    rect := flex_rect()
    return toggle_rect(rect, label, selected)
}

// Like a checkbox, a button that can be pressed and unpressed. Does not manage its own state.
toggle_rect :: proc(rect: rl.Rectangle, label: cstring, selected: bool) -> bool {
    hover := hovered(rect)
    press := hover && rl.IsMouseButtonPressed(.LEFT)
    held := hover && rl.IsMouseButtonDown(.LEFT)
    rl.DrawRectangleRec(rect, button_color(hover, selected, held))
    text_rect(rect, label, color = TEXT_COLOR, align = .Center)
    return press
}

arrow :: proc(vec: ^rl.Vector2, label: cstring, max_mag := INF) {
    rect := flex_rect()
    arrow_rect(rect, vec, label, max_mag)
}

// An alternative vector edit component for direction and magnitude. Mostly used for gravity.
arrow_rect :: proc(rect: rl.Rectangle, vec: ^rl.Vector2, label: cstring, max_mag := INF) {
    arrow_rect := rect
    arrow_rect.width = rect.height
    center := rl.Vector2{arrow_rect.x + arrow_rect.width / 2, arrow_rect.y + arrow_rect.height / 2}

    hover := hovered(arrow_rect)
    key := fmt.ctprintf("arrow#%v", label)
    if hover && rl.IsMouseButtonPressed(.LEFT) {
        state.dragging = key
    }
    active := key == state.dragging
    if active && rl.IsMouseButtonDown(.LEFT) {
        dir := linalg.normalize(state.mouse - center)

        // Snap to axes.
        UNIT_DIRECTIONS :: [?]rl.Vector2{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
        for unit in UNIT_DIRECTIONS {
            if linalg.dot(dir, unit) > 0.99 {
                dir = unit
            }
        }

        // Dragging the arrow changes direction, but maintains magnitude.
        vec^ = linalg.length(vec^) * dir
    }

    rl.DrawRectangleRec(arrow_rect, dark_color(hover, active))
    rl.DrawLineV({center.x, arrow_rect.y + 1}, {center.x, arrow_rect.y + arrow_rect.height}, ACTIVE_BUTTON_COLOR) // vertical
    rl.DrawLineV({arrow_rect.x, center.y}, {arrow_rect.x + arrow_rect.width, center.y}, ACTIVE_BUTTON_COLOR) // horizontal

    direction := linalg.normalize(vec^) if linalg.length(vec^) != 0 else {0, 1}
    end := center + direction * arrow_rect.height / 5
    draw_arrow(center, end, 3, TEXT_COLOR)

    // Magnitude is a float editor. Changing magnitude, maintains direction.
    magnitude_rect := rect
    magnitude_rect.x = arrow_rect.x + arrow_rect.width + 2
    magnitude_rect.width = rect.width - arrow_rect.width

    magnitude := linalg.length(vec^)
    float_rect(magnitude_rect, &magnitude, min = 0, max = max_mag, label = label)
    vec^ = direction * magnitude
}

draw_arrow :: proc(start, end: rl.Vector2, thickness: f32, color: rl.Color) {
    arrow_height := thickness * 3
    arrow_width  := arrow_height / linalg.SQRT_THREE // Ratio in equilateral triangle.

    slope := linalg.normalize(end - start)
    v1 := end + slope * arrow_height  // Pointy-tip, continue along the line.

    // Other 2 arrow-head vertices are perpendicular to the end point.
    // Perpendicular line has negative reciprical slope: -(x2 - x1) / (y2 - y1)
    slope.x, slope.y = slope.y, -slope.x

    v2 := end + slope * arrow_width
    v3 := end - slope * arrow_width

    rl.DrawLineEx(start, end, thickness, color)
    rl.DrawTriangle(v1, v2, v3, color)
}


// Splits a rectangle up into its label and body components.
@(require_results)
label_split_rect :: proc(rect: rl.Rectangle, label: cstring) -> (text, body: rl.Rectangle) {
    if label == nil {
        return {}, rect
    }

    text = rect
    text.height = LABEL_HEIGHT

    body = rect
    body.height -= LABEL_HEIGHT
    body.y += LABEL_HEIGHT

    return
}

@(require_results)
pressed :: #force_inline proc(rect: rl.Rectangle) -> bool {
    return rl.IsMouseButtonPressed(.LEFT) && hovered(rect)
}

@(require_results)
hovered :: #force_inline proc(rect: rl.Rectangle) -> bool {
    return rl.CheckCollisionPointRec(state.mouse, rect)
}

@(require_results)
padding :: #force_inline proc(rect: rl.Rectangle, pad: rl.Vector2) -> rl.Rectangle {
    return {
        rect.x + pad.x,
        rect.y + pad.y,
        rect.width  - 2 * pad.x,
        rect.height - 2 * pad.y,
    }
}

@(require_results)
want_keyboard :: #force_inline proc() -> bool {
    return state.active_input != nil
}

@(require_results)
want_mouse :: #force_inline proc() -> bool {
    return state.hovered_panel != nil || state.dragging != nil || state.button_pressed != nil
}