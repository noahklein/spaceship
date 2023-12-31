package ngui

import rl "vendor:raylib"

Graph :: struct {
    lines: map[cstring]GraphLine,
    lower, upper: f32,
    current: cstring,
    size: int,
}

GraphLine :: struct {
    start: int,
    points: [dynamic]f32,
    color: rl.Color,
}

graph_line_push :: proc(line: ^GraphLine, v: f32) {
    line.points[line.start] = v
    line.start = (line.start + 1) % len(line.points)
}

@(deferred_none=graph_end)
graph_begin :: proc(label: cstring, size: int, upper, lower: f32) -> bool {
    if label not_in state.graphs {
        state.graphs[label] = Graph{ upper = upper, lower = lower, size = size }
    }

    state.graph_curr = label
    return true
}

graph_end :: proc() {
    rect := flex_rect()
    graph_draw_rect(state.graphs[state.graph_curr], rect)

    state.graph_curr = nil
}

graph_line :: proc(line_label: cstring, value: f32, color: rl.Color) {
    assert(state.graph_curr != nil, "graph_line() must be called between graph_begin() and graph_end().")
    graph := &state.graphs[state.graph_curr]

    line, ok := &graph.lines[line_label]
    if !ok {
        graph.lines[line_label] = GraphLine{ color = color }
        line = &graph.lines[line_label]
        resize(&line.points, graph.size)
    }

    graph_line_push(line, value)
}

graph_draw_rect :: proc(graph: Graph, rect: rl.Rectangle) {
    line_rect := rect

    hover := hovered(line_rect)
    rl.DrawRectangleRec(line_rect, dark_color(hover, false))

    for line_label, line in graph.lines {
        inv_line_length := f32(1) / f32(len(line.points))
        for i in 0..<len(line.points)-1 {
            j := i + 1
            if j == line.start do continue // Don't draw line from end to start.

            y1 := line.points[i]
            y2 := line.points[j]

            y1 = 1 - clamp(y1, graph.lower, graph.upper) / graph.upper
            y2 = 1 - clamp(y2, graph.lower, graph.upper) / graph.upper

            y1 *= line_rect.height
            y2 *= line_rect.height

            // x1, x2 := f32(i), f32(j)
            i_norm := i-line.start if line.start <= i  else len(line.points) + (i-line.start)
            j_norm := j-line.start if line.start <= j  else len(line.points) + (j-line.start)

            x1 := f32(i_norm) * inv_line_length
            x2 := f32(j_norm) * inv_line_length

            x1 *= line_rect.width
            x2 *= line_rect.width

            rl.DrawLineV({rect.x+x1, rect.y+y1}, {rect.x+x2, rect.y+y2}, line.color)
        }
    }

    LEGEND_FONT :: FONT / 2
    legend_rect := rect
    legend_rect.height = FONT * 1.2
    legend_rect.width /= 2

    legend_rect.width = 0
    for label in graph.lines {
        legend_rect.width += f32(rl.MeasureText(label, LEGEND_FONT)) + 2 + legend_rect.height + 8
    }
    rl.DrawRectangleRec(legend_rect, {40, 40, 40, 150}) // Legend background rect.

    // Draw legend.
    x: f32 = legend_rect.x
    for label, line in graph.lines {
        width := f32(rl.MeasureText(label, LEGEND_FONT)) + 2 + legend_rect.height

        label_rect := legend_rect
        label_rect.width = width
        label_rect.width /= f32(len(graph.lines))
        label_rect.x = x
        x += width + 8

        color_rect := label_rect
        color_rect.width = color_rect.height
        rl.DrawRectangleRec(padding(color_rect, 3), line.color)

        label_rect.x += color_rect.width
        text_rect(label_rect, label, color = line.color)
    }
}