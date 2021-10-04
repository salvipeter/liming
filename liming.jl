module Liming

using Gtk
import Graphics
using LinearAlgebra

# GUI parameters
window_size = 500
point_size = 5
marching_density = 20
marching_depth = 8

# Global variables
points = []
curve = []
lambda = 8

line(a, b) = p -> (a[2] - b[2]) * p[1] + (b[1] - a[1]) * p[2] - a[2] * b[1] + a[1] * b[2]

function liming(p)
    d = norm(points[end] - points[1])
    n = length(points) - 1
    v = 1
    for i in 1:n
        v *= line(points[i], points[i+1])(p) / d
    end
#    v = sign(v) * abs(v) ^ (2/n)
    v -= (lambda / 100 * line(points[end], points[1])(p) / d) ^ 2
end


# Marching squares

function intersection(p1, v1, p2, v2)
    v1 * v2 > 0 && return nothing
    x = abs(v1) / abs(v2 - v1)
    p1 * (1 - x) + p2 * x
end

function marching(f, topleft, size, max_depth)
    points = [topleft, topleft + [size, 0], topleft + [size, size], topleft + [0, size]]
    values = map(f, points)
    all(map(x -> x < 0, values)) && return []
    all(map(x -> x > 0, values)) && return []
    if max_depth > 0
        half = size / 2
        vcat(marching(f, topleft, half, max_depth - 1),
             marching(f, topleft + [half, 0], half, max_depth - 1),
             marching(f, topleft + [half, half], half, max_depth - 1),
             marching(f, topleft + [0, half], half, max_depth - 1))
    else
        ints = filter(x -> x != nothing,
                      [intersection(points[1], values[1], points[2], values[2]),
                       intersection(points[2], values[2], points[3], values[3]),
                       intersection(points[3], values[3], points[4], values[4]),
                       intersection(points[4], values[4], points[1], values[1])])
        length(ints) == 2 ? ints : []
    end
end

function generate_curve()
    global curve = []
    length(points) < 3 && return
    for i in 1:marching_density, j in 1:marching_density
        ratio = window_size / marching_density
        p = [i, j] * ratio
        append!(curve, marching(liming, p, ratio, marching_depth))
    end
end


# Graphics

function draw_polygon(ctx, poly, closep = false)
    if isempty(poly)
        return
    end
    Graphics.new_path(ctx)
    Graphics.move_to(ctx, poly[1][1], poly[1][2])
    for p in poly[2:end]
        Graphics.line_to(ctx, p[1], p[2])
    end
    if closep && length(poly) > 2
        Graphics.line_to(ctx, poly[1][1], poly[1][2])
    end
    Graphics.stroke(ctx)
end

function draw_segments(ctx, segments)
    for i in 1:2:length(segments)
        Graphics.new_path(ctx)
        Graphics.move_to(ctx, segments[i][1], segments[i][2])
        Graphics.line_to(ctx, segments[i+1][1], segments[i+1][2])
        Graphics.stroke(ctx)
    end
end

draw_callback = @guarded (canvas) -> begin
    ctx = Graphics.getgc(canvas)

    # White background
    Graphics.rectangle(ctx, 0, 0, Graphics.width(canvas), Graphics.height(canvas))
    Graphics.set_source_rgb(ctx, 1, 1, 1)
    Graphics.fill(ctx)

    # Input polygon
    Graphics.set_source_rgb(ctx, 0, 0, 0)
    Graphics.set_line_width(ctx, 1.0)
    draw_polygon(ctx, points, true)

    # Generated curve
    Graphics.set_source_rgb(ctx, 0.8, 0.3, 0)
    Graphics.set_line_width(ctx, 2.0)
    draw_segments(ctx, curve)

    # Input points
    for p in points[1:end]
        Graphics.set_source_rgb(ctx, 0, 0.5, 0)
        Graphics.arc(ctx, p[1], p[2], point_size, 0, 2pi)
        Graphics.fill(ctx)
    end
end


# GUI

mousedown_handler = @guarded (canvas, event) -> begin
    p = [event.x, event.y]
    global clicked = findfirst(points) do q
        norm(p - q) < 10
    end
    if clicked === nothing
        push!(points, p)
        clicked = length(points)
        generate_curve()
        draw(canvas)
    end
end

mousemove_handler = @guarded (canvas, event) -> begin
    global clicked
    points[clicked] = [event.x, event.y]
    generate_curve()
    draw(canvas)
end

function setup_gui()
    win = GtkWindow("Liming Test")
    vbox = GtkBox(:v)

    # Canvas widget
    canvas = GtkCanvas(window_size, window_size)
    canvas.mouse.button1press = mousedown_handler
    canvas.mouse.button1motion = mousemove_handler
    draw(draw_callback, canvas)
    push!(win, vbox)
    push!(vbox, canvas)

    # Reset button
    reset = GtkButton("Start Over")
    signal_connect(reset, "clicked") do _
        global points = []
        global curve = []
        draw(canvas)
    end
    hbox = GtkBox(:h)
    set_gtk_property!(hbox, :spacing, 10)
    push!(vbox, hbox)
    push!(hbox, reset)

    # Lambda spinbutton
    push!(hbox, GtkLabel("Lambda: "))
    lb = GtkSpinButton(0:1:999)
    set_gtk_property!(lb, :value, lambda)
    signal_connect(lb, "value-changed") do sb
        global lambda = get_gtk_property(sb, :value, Int)
        generate_curve()
        draw(canvas)
    end
    push!(hbox, lb)

    generate_curve()
    showall(win)
end

run() = begin setup_gui(); nothing end

end # module
