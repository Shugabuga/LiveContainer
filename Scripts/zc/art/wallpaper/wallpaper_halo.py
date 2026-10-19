"""
zContainer's default wallpaper: the halo behind the phone on Zeus's social
banner (Zeus Box Scripts/og-banner/banner_halo.py), with no phone, framed for a
screen. The halo itself, the BACKGROUND section below, is copied unchanged from
the banner, so the colors, the lens blur and the bloom match it; only where
its shapes' colors wrap around below their centers, which the banner never
shows, is joined up. Units are
centimeters on the plane where the banner's phone stood.

Run:
  blender -b -P wallpaper_halo.py -- <out.png> <width> <height> <samples> <frame width cm> <center x cm> <center y cm>

The frame is <frame width cm> across, centered at (<center x>, <center y>) in
the banner's coordinates: (0, 0) is the middle of the banner, which is 25.8 cm
across and 13.5 cm tall there; y goes up. The camera stays where the banner's
was, so the halo is as soft as on the banner; only the lens changes, to take in
the frame. The PNG is 16 bits per channel, so the slow gradients don't band.
"""
import bpy, bmesh, math, sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0]
WIDTH = int(argv[1])
HEIGHT = int(argv[2])
SAMPLES = int(argv[3])
FRAME_W = float(argv[4])
CENTER_X = float(argv[5])
CENTER_Y = float(argv[6])

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)

def rgba(h):
    return (*lin(h), 1.0)

# --- Shapes ------------------------------------------------------------------

def cubic(p0, p1, p2, p3, steps):
    out = []
    for s in range(1, steps + 1):
        t = s / steps; m = 1 - t
        out.append((m**3 * p0[0] + 3 * m * m * t * p1[0] + 3 * m * t * t * p2[0] + t**3 * p3[0],
                    m**3 * p0[1] + 3 * m * m * t * p1[1] + 3 * m * t * t * p2[1] + t**3 * p3[1]))
    return out

def rounded_rect(w, h, r, steps=8):
    """A rectangle with Apple's continuous corners, centered on the origin."""
    a, b, c, d, e, f, g, i = [v * r for v in (1.52866483, 1.08849299, 0.86840701, 0.66993427, 0.37282392, 0.16123516, 0.065496, 0.022217)]
    W, H = w, h
    segs = [
        ("L", (W - a, 0)),
        ("C", (W - b, 0), (W - c, i), (W - d, g)), ("C", (W - e, f), (W - f, e), (W - g, d)), ("C", (W - i, c), (W, b), (W, a)),
        ("L", (W, H - a)),
        ("C", (W, H - b), (W - i, H - c), (W - g, H - d)), ("C", (W - f, H - e), (W - e, H - f), (W - d, H - g)), ("C", (W - c, H - i), (W - b, H), (W - a, H)),
        ("L", (a, H)),
        ("C", (b, H), (c, H - i), (d, H - g)), ("C", (e, H - f), (f, H - e), (g, H - d)), ("C", (i, H - c), (0, H - b), (0, H - a)),
        ("L", (0, a)),
        ("C", (0, b), (i, c), (g, d)), ("C", (f, e), (e, f), (d, g)), ("C", (c, i), (b, 0), (a, 0)),
    ]
    pts = [(a, 0)]; cur = (a, 0)
    for seg in segs:
        if seg[0] == "L":
            pts.append(seg[1]); cur = seg[1]
        else:
            pts.extend(cubic(cur, seg[1], seg[2], seg[3], steps)); cur = seg[3]
    pts = pts[:-1]
    return [(x - W / 2, (H - y) - H / 2) for x, y in pts]

def flat_mesh(name, outline, uv_size=None):
    """A flat face from an outline, facing +Z, with UVs across `uv_size` if given."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0)) for x, y in outline]
    face = bm.faces.new(verts)
    face.normal_update()
    if face.normal.z < 0:
        face.normal_flip()
    if uv_size:
        uv = bm.loops.layers.uv.new("UVMap")
        w, h = uv_size
        for loop in face.loops:
            x, y = loop.vert.co.x, loop.vert.co.y
            loop[uv].uv = (x / w + 0.5, y / h + 0.5)
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj

# --- The banner's camera ---------------------------------------------------------
# Where the banner's camera stood, from its Look settings (a 50 mm lens framing
# 12.3 / 0.91 cm of height on a 1200 by 630 picture), so the cards behind sit as
# far behind the focus and blur as much.
BANNER_LENS = 50.0
BANNER_VISIBLE_H = 12.3 / 0.91
BANNER_SENSOR_H = 36.0 * 630 / 1200
FSTOP = 22.0
CAM_HEIGHT = 350.0
BLOOM_THRESHOLD = 0.45
BLOOM_STRENGTH = 0.55
BLOOM_SIZE = 0.6

cam_dist = BANNER_LENS / 10 * BANNER_VISIBLE_H / (BANNER_SENSOR_H / 10)
cam_y = -cam_dist
cam_z = CAM_HEIGHT

# ==============================================================================
# BACKGROUND: everything behind the phone. The camera sits at (0, cam_y, cam_z)
# looking along +Y; the phone's face is at y = 0, centered on x = 0, at
# z = PHONE_Z. Anything placed at y > 0 is behind the phone.
#
# A soft arch of light rises behind the phone, like a product hero shot: its
# top is hidden by the phone and its two sides sweep down to the bottom
# corners, turning from Zeus pink on the left to violet on the right. A fainter
# echo of the arch sits further back, a dim plum glow lifts the space right
# behind the phone so its edges read, and a low pool of light warms the base.
#
# Nothing here is geometry: each piece is an emissive card whose shader works
# out how far every point is from a ring (or from a point, for the round
# glows), and turns that into a soft core, a wider glow and a long tail that
# fades into near black. That keeps every edge smooth and free of noise.
# ==============================================================================

world = bpy.data.worlds.new("World"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba("#040306")
scene.world = world

def glow_card(name, behind, shapes, base=None, see_through=False):
    """An emissive card `behind` cm back from the phone, lit by soft shapes.

    Sizes are in cm on the phone's plane, measured from the middle of the frame
    (the frame is about 25.8 by 13.5 there; the phone is 7.8 wide), so moving a
    card back changes only how much the lens softens it, not the layout.

    Each shape is a ring of `radius` around `center`, stretched by `squash`
    (a radius of 0 makes a round glow instead). Its light is made of up to three
    layers, each a (width, brightness) pair: `core` and `glow` fade like a bell
    curve, `tail` fades slowly like light spilling through air. `inner` scales
    how far the light reaches inside the ring. `around` lists (place, color,
    brightness) going around the shape: 0 is the bottom left, 0.25 the left,
    0.5 the top, 0.75 the right. The glow and tail lean toward `tint` by
    `glow_lean` and `tail_lean`, the way light deepens in color as it spreads.
    """
    k = (cam_dist + behind) / cam_dist
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    hn = mat.node_tree.nodes; hl = mat.node_tree.links
    hn.remove(hn["Principled BSDF"])

    def hook(sock, value):
        if isinstance(value, (int, float)):
            sock.default_value = value
        else:
            hl.new(value, sock)

    def op(kind, a, b=None):
        n = hn.new("ShaderNodeMath"); n.operation = kind
        for i, v in enumerate((a, b)):
            if v is not None:
                hook(n.inputs[i], v)
        return n.outputs[0]

    def bell(dist, width):
        # exp(-(d / w)^2): full on the line, fading smoothly both ways.
        q = op("DIVIDE", dist, width)
        return op("EXPONENT", op("MULTIPLY", op("MULTIPLY", q, q), -1.0))

    def spill(dist, width):
        # 1 / (1 + (d / w)^2): a long, gentle tail.
        q = op("DIVIDE", dist, width)
        return op("DIVIDE", 1.0, op("ADD", 1.0, op("MULTIPLY", q, q)))

    def vec(kind, a, b=None, scale=None):
        n = hn.new("ShaderNodeVectorMath"); n.operation = kind
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, tuple):
                n.inputs[i].default_value = v[:3]
            else:
                hl.new(v, n.inputs[i])
        if scale is not None:
            hook(n.inputs["Scale"], scale)
        return n.outputs[0]

    def mix_color(fac, a, b):
        n = hn.new("ShaderNodeMix"); n.data_type = "RGBA"
        sock_of = {x.identifier: x for x in n.inputs}
        hook(sock_of["Factor_Float"], fac)
        for sock, v in ((sock_of["A_Color"], a), (sock_of["B_Color"], b)):
            if isinstance(v, tuple):
                sock.default_value = v
            else:
                hl.new(v, sock)
        return next(x for x in n.outputs if x.identifier == "Result_Color")

    tc = hn.new("ShaderNodeTexCoord")
    xyz = hn.new("ShaderNodeSeparateXYZ"); hl.new(tc.outputs["Object"], xyz.inputs[0])
    total = None
    for s in shapes:
        sx, sy = s.get("squash", (1.0, 1.0))
        du = op("DIVIDE", op("SUBTRACT", xyz.outputs["X"], s["center"][0]), sx)
        dv = op("DIVIDE", op("SUBTRACT", xyz.outputs["Y"], s["center"][1]), sy)
        radius = op("SQRT", op("ADD", op("MULTIPLY", du, du), op("MULTIPLY", dv, dv)))
        signed = op("SUBTRACT", radius, s.get("radius", 0.0))
        inside = op("LESS_THAN", signed, 0.0)
        reach = op("ADD", 1.0, op("MULTIPLY", inside, s.get("inner", 1.0) - 1.0))
        off = op("DIVIDE", op("ABSOLUTE", signed), reach)

        place = op("ADD", op("DIVIDE", op("ARCTAN2", du, dv), 2 * math.pi), 0.5)
        ramp = hn.new("ShaderNodeValToRGB"); hl.new(place, ramp.inputs["Fac"])
        stops = s["around"]
        els = ramp.color_ramp.elements
        def put(e, stop):
            e.position = stop[0]; e.color = (*lin(stop[1]), stop[2])
        put(els[0], stops[0]); put(els[1], stops[-1])
        for stop in stops[1:-1]:
            put(els.new(stop[0]), stop)
        ramp.color_ramp.interpolation = "B_SPLINE"

        tint = rgba(s.get("tint", "#000000"))
        layers = [(s.get("core"), bell, 0.0), (s.get("glow"), bell, s.get("glow_lean", 0.0)),
                  (s.get("tail"), spill, s.get("tail_lean", 0.0))]
        for layer, fade, lean in layers:
            if not layer:
                continue
            width, amount = layer
            strength = op("MULTIPLY", op("MULTIPLY", fade(off, width), amount), ramp.outputs["Alpha"])
            color = mix_color(lean, ramp.outputs["Color"], tint) if lean else ramp.outputs["Color"]
            part = vec("SCALE", color, scale=strength)
            total = part if total is None else vec("ADD", total, part)
    if base:
        total = vec("ADD", total, rgba(base))

    em = hn.new("ShaderNodeEmission")
    hl.new(total, em.inputs["Color"]); em.inputs["Strength"].default_value = 1.0
    shader = em.outputs[0]
    if see_through:
        # Add this card's light over whatever is behind it instead of hiding it.
        add = hn.new("ShaderNodeAddShader"); clear = hn.new("ShaderNodeBsdfTransparent")
        hl.new(shader, add.inputs[0]); hl.new(clear.outputs[0], add.inputs[1])
        shader = add.outputs[0]
    hl.new(shader, hn["Material Output"].inputs["Surface"])
    # The phone barely sees these cards, so skip sampling them as lamps.
    mat.cycles.emission_sampling = "NONE"

    card = flat_mesh(name, rounded_rect(90, 70, 1))
    card.data.materials.append(mat)
    card.location = (0, behind, cam_z)
    card.rotation_euler = (math.radians(90), 0, 0)
    card.scale = (k, k, k)
    return card

# The arch. Its top sits behind the phone, so the sides appear from behind the
# phone's upper edges and sweep down to the bottom corners. The inside edge is
# a little crisper than the outside one, like a rim of light behind a disc.
ARCH = dict(
    center=(0.0, -6.0), radius=9.6, squash=(1.15, 1.0), inner=0.5,
    core=(0.55, 0.53), glow=(1.5, 0.33), tail=(4.0, 0.10),
    tint="#2a0c5a", glow_lean=0.3, tail_lean=0.8,
    around=[(0.10, "#8a1868", 0.45), (0.25, "#de238c", 0.72), (0.38, "#ee3a9c", 0.92),
            (0.50, "#c94fd0", 1.0), (0.62, "#a24ae8", 1.0), (0.75, "#8a3ef0", 0.82),
            (0.90, "#4a2299", 0.5)],
)

# A dim plum glow right behind the phone, so its dark steel edges stand out.
BACKLIGHT = dict(
    center=(0.0, -3.0), squash=(1.0, 2.2), glow=(5.0, 0.14),
    around=[(0.0, "#7a2280", 1.0), (0.25, "#8a2088", 1.0), (0.5, "#7a2a90", 1.0),
            (0.75, "#64289a", 1.0), (1.0, "#7a2280", 1.0)],
)

# A low, wide pool of light along the bottom edge.
POOL = dict(
    center=(0.0, -8.0), squash=(2.6, 1.0), glow=(3.0, 0.20), tail=(3.6, 0.05),
    tint="#2a0c5a", glow_lean=0.2, tail_lean=0.6,
    around=[(0.0, "#7a2a9a", 1.0), (0.25, "#b0237f", 1.0), (0.5, "#a0308f", 1.0),
            (0.75, "#6a2ab0", 1.0), (1.0, "#7a2a9a", 1.0)],
)

# The echo: a larger, much fainter arch further back, softened by the lens.
ECHO = dict(
    center=(0.0, -6.6), radius=11.8, squash=(1.12, 1.0),
    core=(0.40, 0.08), glow=(1.3, 0.05),
    around=[(0.10, "#5a1a6a", 0.4), (0.30, "#a03090", 0.9), (0.50, "#8a40c0", 1.0),
            (0.70, "#6a3ad0", 0.9), (0.90, "#3a1a80", 0.4)],
)

# --- Wallpaper only: close the rings at the bottom ---------------------------
# The banner never shows what's straight below a shape's center, where its
# colors wrap around from place 1 back to place 0. A wallpaper does, and two
# things make a hard vertical seam there: the arch and its echo end on the
# pink bottom left (0.1) and the violet bottom right (0.9), and a B-spline
# ramp doesn't land exactly on its end stops, so even equal ends differ.
# Ending the arch and the echo on one blended color, dimmer than their sides,
# lets them fade out at the bottom, and a guard stop just inside each end makes
# every wrap exact.
def close_at_bottom(shape, color=None, alpha=None):
    stops = shape["around"]
    if color is not None:
        stops = [(0.0, color, alpha), *stops, (1.0, color, alpha)]
    end = stops[0]
    shape["around"] = [end, (0.03, end[1], end[2]), *stops[1:-1], (0.97, end[1], end[2]), (1.0, end[1], end[2])]

close_at_bottom(ARCH, "#6a1d80", 0.16)
close_at_bottom(ECHO, "#4a1a75", 0.12)
close_at_bottom(BACKLIGHT)
close_at_bottom(POOL)

glow_card("HaloEcho", 90.0, [ECHO], base="#040306")
glow_card("Halo", 40.0, [ARCH, BACKLIGHT, POOL], see_through=True)

# ==============================================================================
# END BACKGROUND
# ==============================================================================


# --- Camera, framed on the wallpaper ---------------------------------------------
# The cards are parallel to the sensor, so moving the camera sideways or up only
# moves the picture, and a longer or shorter lens only crops it.

cam_data = bpy.data.cameras.new("Camera")
cam_data.sensor_fit = "HORIZONTAL"; cam_data.sensor_width = 36.0
cam_data.lens = 36.0 * cam_dist / FRAME_W
cam_data.clip_start = 1.0
cam_data.clip_end = 5000000
cam_data.dof.use_dof = True
cam_data.dof.focus_distance = cam_dist
# Blender sizes the aperture as if a unit were a meter; this scene is in centimeters.
cam_data.dof.aperture_fstop = FSTOP / 100
cam = bpy.data.objects.new("Camera", cam_data)
cam.location = (CENTER_X, cam_y, cam_z + CENTER_Y)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam

# --- Bloom, as on the banner (with no phone to leave out) -------------------------

scene.render.engine = "CYCLES"
comp = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
comp.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
rl = comp.nodes.new("CompositorNodeRLayers")
rl.scene = scene
rl.layer = scene.view_layers[0].name
gl = comp.nodes.new("CompositorNodeGlare")
gl.inputs["Type"].default_value = "Bloom"
gl.inputs["Quality"].default_value = "High"
gl.inputs["Threshold"].default_value = BLOOM_THRESHOLD
gl.inputs["Strength"].default_value = BLOOM_STRENGTH
gl.inputs["Size"].default_value = BLOOM_SIZE
comp.links.new(rl.outputs["Image"], gl.inputs["Image"])
add = comp.nodes.new("ShaderNodeMix"); add.data_type = "RGBA"; add.blend_type = "ADD"
next(s for s in add.inputs if s.identifier == "Factor_Float").default_value = 1.0
comp.links.new(rl.outputs["Image"], next(s for s in add.inputs if s.identifier == "A_Color"))
comp.links.new(gl.outputs["Glare"], next(s for s in add.inputs if s.identifier == "B_Color"))
go = comp.nodes.new("NodeGroupOutput")
comp.links.new(next(s for s in add.outputs if s.identifier == "Result_Color"), go.inputs[0])
scene.compositing_node_group = comp
scene.render.use_compositing = True

# --- Render ------------------------------------------------------------------

scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 4
scene.render.resolution_x = WIDTH
scene.render.resolution_y = HEIGHT
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.image_settings.color_depth = "16"
scene.render.image_settings.compression = 100
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
