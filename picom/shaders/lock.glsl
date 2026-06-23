#version 330
#define PI 3.14159265
#define BORDER 200
#define WAVE_SPEED 1.0
#define WAVE_FREQUENCY 1.0
#define WAVE_AMPLITUDE 10.0
#define BASE_COLOR vec4(0.141, 0.153, 0.227, 1)
#define BG_COLOR vec4(0, 0, 0, 1)


in vec2 texcoord;             // texture coordinate of the fragment
uniform sampler2D tex;        // texture of the window

uniform float time; // Time in miliseconds.

// Colour of the CRT "flash" sweep that runs down the orb. Set per-fragment in
// window_shader() from the auth state, so the sweep itself signals it: white
// idle, mauve typing, orange verifying, red wrong, green on a real unlock.
vec3 g_flash_color = vec3(1.0);

ivec2 window_size = textureSize(tex, 0); // Size of the window
ivec2 window_center = ivec2(window_size.x/2, window_size.y/2);
const float icon_factor = 16.0;  // orb radius = window_height / icon_factor (≈112 @ 1800)
float icon_radius = window_size.y/icon_factor;
const float shadow_cutoff = 1; // How "early" the shadow starts affecting 
                                 // pixels close to the edges
                                 // I'd keep this value very close to 1
const int shadow_intensity = 3; // Intensity level of the shadow effect (from 1 to 5)
float window_diagonal = length(window_size); // Diagonal of the window
int wss = min(window_size.x, window_size.y); // Window smallest side, useful when squaring windows

const float flash_speed = 75.0;  // Speed of the flash line in pixels per second (≈3s per pass)
const float bright_line_intensity = 0.7; // Max brightness added by the sharp line (can be > 1 for HDR look)
const float bright_line_sharpness = 3.0; // Controls how narrow the bright line is (smaller = sharper)
const float falloff_intensity = 0.35;    // Max brightness added by the falloff glow
const float falloff_height = 60.0;       // How many pixels above the line the falloff extends
const float RING_OUTER_PAD = 4.0;        // thin visible ring (pure decoration): px past the orb edge

// These shaders work by using a pinhole camera and raycasting
// The window 3d objects will always be (somewhat) centered at (0, 0, 0)
struct pinhole_camera
{
    float focal_offset; // Distance along the Z axis between the camera 
                        // center and the focal point. Use negative values
                        // so the image doesn't flip
                        // This kinda works like FOV in games

    // Transformations 
    // Use these to modify the coordinate system of the camera plane
    vec3 rotations; // Rotations in radians around each axis 
                    // The camera plane rotates around 
                    // its center point, not the origin

    vec3 translations; // Translations in pixels along each axis

    vec3 deformations; // Deforms the camera. Higher values on each axis
                       // means the window will be squashed in that axis

    // ---------------------------------------------------------------// 
    
    // "Aftervalues" 
    // These will be set later with setup_camera(), leave them as 0
    vec3 base_x;
    vec3 base_y;
    vec3 base_z;
    vec3 center_point;
    vec3 focal_point;
};


// Sets up a camera by applying transformations and 
// calculating xyz vector basis 
pinhole_camera setup_camera(pinhole_camera camera, float ppa)
{
    // Apply translations
    camera.center_point += camera.translations;

    // Apply rotations 
    // We initialize our vector basis as normalized vectors
    // in each axis * our deformations vector
    camera.base_x = vec3(camera.deformations.x, 0, 0);
    camera.base_y = vec3(0, camera.deformations.y, 0);
    camera.base_z = vec3(0, 0, camera.deformations.z);


    // Then we rotate them around following our rotations vector:
    // First save these values to avoid redundancy
    float cosx = cos(camera.rotations.x);
    float cosy = cos(camera.rotations.y);
    float cosz = cos(camera.rotations.z);
    float sinx = sin(camera.rotations.x);
    float siny = sin(camera.rotations.y);
    float sinz = sin(camera.rotations.z);
    
    // Declare a buffer vector we will use to apply multiple changes at once
    vec3 tmp = vec3(0);

    // Rotations for base_x:
    tmp = camera.base_x;
    // X axis:
    tmp.y =  camera.base_x.y * cosx - camera.base_x.z * sinx;
    tmp.z =  camera.base_x.y * sinx + camera.base_x.z * cosx;
    camera.base_x = tmp;
    // Y axis:
    tmp.x =  camera.base_x.x * cosy + camera.base_x.z * siny;
    tmp.z = -camera.base_x.x * siny + camera.base_x.z * cosy;
    camera.base_x = tmp;
    // Z axis:
    tmp.x =  camera.base_x.x * cosz - camera.base_x.y * sinz;
    tmp.y =  camera.base_x.x * sinz + camera.base_x.y * cosz;
    camera.base_x = tmp;

    // Rotations for base_y:
    tmp = camera.base_y;
    // X axis:
    tmp.y =  camera.base_y.y * cosx - camera.base_y.z * sinx;
    tmp.z =  camera.base_y.y * sinx + camera.base_y.z * cosx;
    camera.base_y = tmp;
    // Y axis:
    tmp.x =  camera.base_y.x * cosy + camera.base_y.z * siny;
    tmp.z = -camera.base_y.x * siny + camera.base_y.z * cosy;
    camera.base_y = tmp;
    // Z axis:
    tmp.x =  camera.base_y.x * cosz - camera.base_y.y * sinz;
    tmp.y =  camera.base_y.x * sinz + camera.base_y.y * cosz;
    camera.base_y = tmp;

    // Rotations for base_z: 
    tmp = camera.base_z;
    // X axis:
    tmp.y =  camera.base_z.y * cosx - camera.base_z.z * sinx;
    tmp.z =  camera.base_z.y * sinx + camera.base_z.z * cosx;
    camera.base_z = tmp;
    // Y axis:
    tmp.x =  camera.base_z.x * cosy + camera.base_z.z * siny;
    tmp.z = -camera.base_z.x * siny + camera.base_z.z * cosy;
    camera.base_z = tmp;
    // Z axis:
    tmp.x =  camera.base_z.x * cosz - camera.base_z.y * sinz;
    tmp.y =  camera.base_z.x * sinz + camera.base_z.y * cosz;
    camera.base_z = tmp;

    // Now that we have our transformed 3d orthonormal base 
    // we can calculate our focal point 
    camera.focal_point = camera.center_point + camera.base_z * camera.focal_offset;

    // Return our set up camera
    return camera;
}
// Helper function for the RGB shift (chromatic aberration)
vec2 curve(vec2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;    
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}


vec4 apply_flash_effect(vec4 color, vec2 coords) {
    // 1. Calculate the current vertical position of the flash line.
    //    Sweep the whole indicator unit (orb + ring band) and repeat, so the scan
    //    crosses it on every pass instead of spending most of its cycle out on the
    //    (invisible) wallpaper. ~5s per pass at flash_speed 50 — a calm CRT sweep.
    float reach = icon_radius + RING_OUTER_PAD;
    float top   = float(window_center.y) - reach;
    float flash_y = top + mod(time * (flash_speed / 1000.0), 2.0 * reach);

    // 2. Calculate the brightness contribution from the sharp bright line
    float distance_from_line = abs(coords.y - flash_y);
    // This creates a very sharp peak at distance 0, falling off quickly.
    // The max value is bright_line_intensity.
    // The '+ 1.0' prevents division by zero and normalizes the peak.
    float bright_line_factor = bright_line_intensity / (pow(distance_from_line / bright_line_sharpness, 2.0) + 1.0);

    // 3. Calculate the brightness contribution from the falloff (above the line)
    float falloff_factor = 0.0;
    float distance_above_line = flash_y - coords.y; // Positive if current pixel is above the line

    if (distance_above_line > 0.0) {
        // Use smoothstep for a gradual fade from falloff_intensity at the line (distance_above_line = 0)
        // down to 0 brightness at falloff_height pixels above the line.
        falloff_factor = falloff_intensity * (1.0 - smoothstep(0.0, falloff_height, distance_above_line));
    }

    // 4. Combine the effects. Adding white-hot brightness (the old `+=`) blew the
    //    line's core past 1.0 to WHITE, hiding its colour. Instead, tint the pixel
    //    TOWARD the auth-state colour at the line, then add a small same-colour
    //    glow — so the scan reads clearly as red (wrong) / green (unlock) / white
    //    (idle) / orange (verifying) / mauve (typing), not white.
    float total_flash_brightness = bright_line_factor + falloff_factor;
    color.rgb = mix(color.rgb, g_flash_color, clamp(total_flash_brightness, 0.0, 1.0));
    color.rgb += g_flash_color * total_flash_brightness * 0.15;  // tiny same-colour glow, no white blowout

    // Optional: Clamp the result if you want to prevent colors going significantly above 1.0
    // color.rgb = clamp(color.rgb, 0.0, 1.0); // Hard clamp
    // color.rgb = min(color.rgb, vec3(1.5)); // Allow some over-brightening

    return color;
}

// CRT effect shader
vec4 crt_shader(vec2 coords)
{
    // Parameters - feel free to adjust these
    float scanline_intensity = 0.125;      // How dark the scanlines are
    float rgb_shift = 2.0;                 // How much RGB shifting occurs
    float vignette_intensity = 0.2;        // How dark the corners get
    float screen_curve = 0.5;             // How much screen curvature
    
    // Convert coords to UV space (0 to 1)
    vec2 uv = coords / vec2(window_size);
    
    // Apply screen curvature
    vec2 curved_uv = mix(uv, curve(uv), screen_curve);
    
    // If UV is outside bounds, return black
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || 
        curved_uv.y < 0.0 || curved_uv.y > 1.0)
        return vec4(0.0, 0.0, 0.0, 1.0);
    
    // Convert curved UV back to pixel coordinates
    vec2 screen_pos = curved_uv * vec2(window_size);
    
    // Chromatic aberration
    vec4 color;
    color.r = texelFetch(tex, ivec2(screen_pos + vec2(rgb_shift, 0.0)), 0).r;
    color.g = texelFetch(tex, ivec2(screen_pos), 0).g;
    color.b = texelFetch(tex, ivec2(screen_pos - vec2(rgb_shift, 0.0)), 0).b;
    color.a = 1.0;
    
    // Scanlines
    float scanline = sin(screen_pos.y * 0.7) * 0.5 + 0.5;
    color.rgb *= 1.0 - (scanline * scanline_intensity);
    
    // Vertical sync lines (more subtle)
    float vertical_sync = sin(screen_pos.x * 2.0) * 0.5 + 0.5;
    color.rgb *= 1.0 - (vertical_sync * scanline_intensity * 0.5);
    
    // Vignette (darker corners)
    vec2 center_dist = curved_uv - vec2(0.5);
    float vignette = 1.0 - (dot(center_dist, center_dist) * vignette_intensity);
    color.rgb *= vignette;
    
    // Brightness and contrast adjustments
    color.rgb *= 1.2;  // Brightness boost
    color.rgb = pow(color.rgb, vec3(1.2)); // Contrast boost
    
    // Add subtle noise to simulate CRT noise
    float noise = fract(sin(dot(curved_uv, vec2(12.9898, 78.233))) * 43758.5453);
    color.rgb += (noise * 0.02 - 0.01); // Very subtle noise
    
    return color;
}

// Gets a pixel from the end of a ray projected to an axis
vec4 get_pixel_from_projection(float t, pinhole_camera camera, vec3 focal_vector, float ppa)
{
    // If the point we end up in is behind our camera, don't "render" it
    if (t < 1)
    {
        return BG_COLOR;
    }

    // Then we multiply our focal vector by t and add our focal point to it
    // to end up in a point inside the window plane 
    vec3 intersection = focal_vector * t + camera.focal_point;
    

    // Save necessary coordinates
    vec2 cam_coords = intersection.xy;
    float cam_coords_length = length(cam_coords);

    // If pixel is outside of our icon region
    // return an empty pixel
    float local_icon_radius = icon_radius - 50 + 60 * ppa;
    if (cam_coords_length > local_icon_radius)
    {
        return vec4(0);
    }

    // Fetch the pixel
    cam_coords += window_center;
    vec4 pixel = texelFetch(tex, ivec2(cam_coords), 0);
    pixel = crt_shader(cam_coords);
    pixel = apply_flash_effect(pixel, cam_coords);
    if (pixel.xyz == vec3(0))
    {
        return BASE_COLOR;
    }

    pixel.w = 0.9;
    return pixel;
}

// Combines colors using alpha
// Got this from https://stackoverflow.com/questions/64701745/how-to-blend-colours-with-transparency
// Not sure how it works honestly lol
vec4 alpha_composite(vec4 color1, vec4 color2)
{
    float ar = color1.w + color2.w - (color1.w * color2.w);
    float asr = color2.w / ar;
    float a1 = 1 - asr;
    float a2 = asr * (1 - color1.w);
    float ab = asr * color1.w;
    vec4 outcolor;
    outcolor.xyz = color1.xyz * a1 + color2.xyz * a2 + color2.xyz * ab;
    outcolor.w = ar;
    return outcolor;
}

// Gets a pixel through the camera using coords as coordinates in
// the camera plane
vec4 get_pixel_through_camera(vec2 coords, pinhole_camera camera, float ppa)
{
    // Offset coords
    coords -= window_center;

    // Find the pixel 3d position using the camera vector basis
    vec3 pixel_3dposition =   camera.center_point 
                            + coords.x * camera.base_x 
                            + coords.y * camera.base_y;

    // Get the vector going from the focal point to the pixel in 3d sapace
    vec3 focal_vector = pixel_3dposition - camera.focal_point;

    // Following the sphere EQ (with Y axis as center)
    // x^2 + y^2 + z^2 = r^2
    float r = icon_radius * 2 / PI + 33;

    // Then there's a line going from our focal point to the sphere
    // which we can describe as:
    // x(t) = focal_point.x + focal_vector.x * t
    // y(t) = focal_point.y + focal_vector.y * t
    // z(t) = focal_point.z + focal_vector.z * t
    // We substitute x, y and z with x(t) and z(t) in the sphere EQ
    // Solving for t we get a cuadratic EQ which we solve with the 
    // cuadratic formula:

    // We calculate focal vector and focal point values squared 
    // to avoid redundancy
    vec3 fvsqr;
    vec3 fpsqr;

    fvsqr.x = pow(focal_vector.x,2);
    fvsqr.y = pow(focal_vector.y,2);
    fvsqr.z = pow(focal_vector.z,2);

    fpsqr.x = pow(camera.focal_point.x,2);
    fpsqr.y = pow(camera.focal_point.y,2);
    fpsqr.z = pow(camera.focal_point.z,2);

    // Coeficients of our EQ
    float a = fvsqr.x + fvsqr.y + fvsqr.z;
    float b = 2*(camera.focal_point.x*focal_vector.x
                +camera.focal_point.y*focal_vector.y
                +camera.focal_point.z*focal_vector.z);
    float c = fpsqr.x + fpsqr.y + fpsqr.z - pow(r,2);

    // If there are no real roots, then there's no intersection and we 
    // return an empty pixel
    float formulasqrt = pow(b,2)-4*a*c;
    if (formulasqrt < 0) 
    {
        return vec4(0);
    }

    vec2 t[2]; // A float should be used for this instead, but the shader
               // isn't rendered correctly when I use a float
               // Cursed, but it works

    // Solve with general formula
    t[0].x = (-b + sqrt(formulasqrt))/(2*a);
    t[1].x = (-b - sqrt(formulasqrt))/(2*a);
    t[0].y = 0;
    t[1].y = 0;
    

    // Bubble sort to know which intersections happen first
    for (int i = 0; i < t.length(); i++)
    {
        for (int j = 0; j < t.length(); j++)
        {
            if (t [j].x > t[j+1].x)
            {
                vec2 tmp = t[j];
                t[j] = t[j+1];
                t[j+1] = tmp;
            }
        }
    }

    // Then we go through each one of the intersections in order 
    // and mix pixels together using alpha
    vec4 blended_pixels = vec4(0);
    for (int i = 0; i < t.length(); i++)
    {
        // We get the pixel through projection
        vec4 projection_pixel = get_pixel_from_projection(t[i].x, 
                                                          camera,
                                                          focal_vector, ppa);
        if (projection_pixel.w > 0.0)
        {
            // Blend the pixel using alpha
            blended_pixels = alpha_composite(projection_pixel, blended_pixels);
        }
    }
    return blended_pixels;
}

// Darkens a pixels near the edges
vec4 calc_opacity(vec4 color, vec2 coords)
{
    // If shadow intensity is 0, change nothing
    if (shadow_intensity == 0)
    {
        return color;
    }

    // Get how far the coords are from the center
    vec2 distances_from_center = abs(window_center - coords);

    // Darken pixels close to the edges of the screen in a polynomial fashion
    float opacity = 1;
    opacity *= -pow((distances_from_center.y/window_center.y)*shadow_cutoff, 
                       (5/shadow_intensity)*2)+1;
    opacity *= -pow((distances_from_center.x/window_center.x)*shadow_cutoff, 
                       (5/shadow_intensity)*2)+1;
    color.w *= opacity;
    color.w = max(1 - color.w, 0.5);

    return color;
}

// The shader gets no auth state from i3lock directly — only `time` and the
// window pixels. So we recover the state by reading i3lock's indicator RING out
// of the texture: it is painted white when idle, green on a correct password,
// red on a wrong one, and shows a mauve key-highlight arc on each keystroke.
// We sample a circle of points at the ring radius and classify by Catppuccin
// macchiato hue. Returns 0 idle, 1 typing, 2 wrong, 3 correct; `tint` is the
// colour to push the orb toward.
const float RING_SAMPLE_RADIUS = 64.0;    // centre of the wide band bracketing i3lock's DPI-scaled ring (--radius 40, scale ~1.25-2x)
// Ring colours (Catppuccin macchiato): idle = white, verifying = peach/orange,
// wrong = red, typing highlight = mauve. We classify by hue. Note "correct" is
// NOT a ring colour — i3lock paints the orange verify ring for ANY password, so
// success is detected separately (via the window's destroy fade, see below).
// Returns: 0 idle, 1 typing, 2 wrong, 4 verifying.
int detect_auth_state()
{
    int orange = 0, red = 0, mauve = 0;
    // i3lock draws its indicator through a DPI-scaled cairo context
    // (cairo_scale(scaling_factor)), so the ring lands at radius * ~1.25, NOT the
    // raw --radius — while the orb (drawn by picom in raw pixels) is unscaled. We
    // don't know the exact factor, so scan a WIDE band (60..90) that brackets the
    // scaled ring for any factor ~1.1–1.4, at many angles (dense enough to also
    // catch the small mauve key-highlight ARC of a keystroke), rounded to texel.
    for (int ri = 0; ri < 5; ri++)
    {
        float rad = RING_SAMPLE_RADIUS - 24.0 + float(ri) * 12.0;  // 40,52,64,76,88
        for (int i = 0; i < 24; i++)
        {
            float a = float(i) / 24.0 * 2.0 * PI;
            vec2 p = vec2(window_center) + rad * vec2(cos(a), sin(a));
            vec3 s = texelFetch(tex, ivec2(p + 0.5), 0).rgb;   // round to nearest
            if (max(max(s.r, s.g), s.b) < 0.15) continue;  // empty / background
            if (s.b > s.r + 0.04 && s.r > s.g + 0.05)      // mauve  c6a0f6 (b>r>g); margin keeps lavender out
                mauve++;
            else if (s.r > s.g + 0.08)                     // r-dominant: peach or red
            {
                if (s.g > s.b + 0.03) orange++;            // peach  f5a97f (g>b)
                else                  red++;               // red    ed8796 (b>=g)
            }
        }
    }
    // Priority: wrong > verifying > typing. The mauve arc is small/brief, so a
    // single hit counts as typing.
    // i3lock's verify ring and typing key-highlight are BOTH mauve now (no orange
    // anywhere), so we split them by coverage: a full ring lights up many mauve
    // samples, a keystroke arc only a few. (orange is unused but kept harmless.)
    if (red    >= 3)  return 2; // wrong     (full red ring)
    if (mauve  >= 18) return 4; // verifying (full mauve ring)
    if (mauve  >= 2)  return 1; // typing    (small mauve key-highlight arc)
    return 0;                   // idle
}

// Bilinear sample of the equirectangular avatar (a W x H rect centred in the lock
// image), with the longitude (u) wrapped so the last column blends back into the
// first — smooth (no pixelation) and seamless at the back of the globe.
vec3 sample_pano(float u, float vv, float W, float H)
{
    vec2 base = vec2(window_center) - vec2(W, H) * 0.5;   // rect top-left in the image
    float fx = fract(u) * W;
    float fy = clamp(vv, 0.0, 1.0) * (H - 1.0);
    int Wi = int(W);
    int x0 = int(floor(fx)); float tx = fx - float(x0);
    int y0 = int(floor(fy)); float ty = fy - float(y0);
    int x1 = x0 + 1; if (x1 >= Wi) x1 = 0;                 // wrap longitude
    int y1 = min(y0 + 1, int(H) - 1);
    ivec2 b = ivec2(base);
    vec3 c00 = texelFetch(tex, b + ivec2(x0, y0), 0).rgb;
    vec3 c10 = texelFetch(tex, b + ivec2(x1, y0), 0).rgb;
    vec3 c01 = texelFetch(tex, b + ivec2(x0, y1), 0).rgb;
    vec3 c11 = texelFetch(tex, b + ivec2(x1, y1), 0).rgb;
    return mix(mix(c00, c10, tx), mix(c01, c11, tx), ty);
}

// Default window post-processing:
// 1) invert color
// 2) opacity / transparency
// 3) max-brightness clamping
// 4) rounded corners
vec4 default_post_processing(vec4 c);

vec4 window_shader() {
    vec4 craw = texelFetch(tex, ivec2(texcoord), 0);
    float post_proc_alpha = default_post_processing(craw).w; // window-destroy fade => unlock

    float dist = distance(texcoord, vec2(window_center));
    float R = icon_radius;
    float ring_outer = R + RING_OUTER_PAD;

    // Everything beyond the indicator unit is just the CRT wallpaper. Handle it
    // FIRST and return, so we never run auth detection on the millions of
    // background fragments (it only needs to run on the orb + ring).
    if (dist > ring_outer)
    {
        vec4 bg = crt_shader(texcoord);
        bg.w = 1.0;
        bg = calc_opacity(bg, texcoord);
        vec4 fcb = default_post_processing(bg);
        fcb.w = 1.0;
        return fcb;
    }

    // ---- ONE auth state for the whole indicator (orb + ring + scan), computed
    //      once here and shared, so the pieces can never disagree or look
    //      disconnected. Green = the window-destroy fade (the only sure "unlock"
    //      signal); the rest is read from i3lock's ring. The painted colours are
    //      deliberately vivid and far apart so wrong/verify/typing never blur.
    int  auth;                                  // 0 idle 1 typing 2 wrong 3 unlock 4 verifying
    vec3 state_col;
    if (post_proc_alpha < 0.99) { auth = 3; state_col = vec3(0.651, 0.855, 0.584); } // Catppuccin green unlock
    else
    {
        auth = detect_auth_state();
        if      (auth == 2) state_col = vec3(1.00, 0.13, 0.13);   // red     invalid
        else if (auth == 4) state_col = vec3(0.78, 0.55, 1.00);   // purple  validating (steady)
        else if (auth == 1) state_col = vec3(0.78, 0.55, 1.00);   // purple  typing (flickers)
        else                state_col = vec3(1.00, 1.00, 1.00);   // white   idle (default)
    }
    // A single brightness envelope makes the whole unit "breathe" together: a quick
    // flicker while typing, a gentle pulse while verifying, steady otherwise.
    float pulse = 1.0;
    if (auth == 1) pulse = 0.50 + 0.50 * sin(time / 65.0);   // typing is the ONLY state that flickers
    g_flash_color = state_col;                   // the scan line shares this colour

    vec4 c;
    if (dist <= R)
    {
        // ---- Spinning equirectangular globe ----
        // The icon circle is an orthographic sphere of radius R: reconstruct the
        // surface normal, spin it around Y by `time`, and read the avatar (a centred
        // AVATAR_W x AVATAR_H panorama) as an equirectangular map — wraps seamlessly.
        vec2 d = texcoord - vec2(window_center);
        float z = sqrt(max(0.0, R*R - dot(d, d)));          // front-hemisphere depth
        vec3 nrm = vec3(d.x, d.y, z) / R;                   // surface normal
        float ang = time / 1200.0;                          // spin speed (rad)
        float ca = cos(ang), sa = sin(ang);
        vec3 rn = vec3(nrm.x*ca + nrm.z*sa, nrm.y, -nrm.x*sa + nrm.z*ca);
        float u  = 0.5 + atan(rn.x, rn.z) / (2.0 * PI);     // longitude
        float vv = 0.5 + asin(clamp(rn.y, -1.0, 1.0)) / PI; // latitude
        const float AVATAR_W = 198.0;                       // must match make-lock-image diameter
        const float AVATAR_H = 97.0;                        // equirect pano height (1440/2912 * 198)
        vec3 pano = sample_pano(u, vv, AVATAR_W, AVATAR_H); // bilinear + wrapped
        vec4 px = vec4(pano, 1.0);
        float scl = sin(texcoord.y * 0.7) * 0.5 + 0.5;      // CRT scanline
        px.rgb *= 1.0 - scl * 0.10;
        px = apply_flash_effect(px, texcoord);              // shared coloured sweep
        float sh = 0.75 + 0.25 * nrm.z;                     // gentle spherical shading (high floor: no dark rim ring)
        c = vec4(px.rgb * sh, 1.0);

        // Echo the state colour into the globe (× pulse) so the orb agrees with the
        // ring. Lighter than the ring so the planet still reads through it.
        float wash = 0.0;
        if      (auth == 2) wash = 0.52;                    // wrong  (bold, dominates the planet)
        else if (auth == 3) wash = 0.40;                    // unlock
        else if (auth == 4) wash = 0.16;                    // verifying
        else if (auth == 1) wash = 0.18;                    // typing
        c.rgb = mix(c.rgb, state_col * pulse, wash);
    }
    else
    {
        // ---- Unified state ring, drawn by US right at the orb's edge ----
        // It is ALWAYS state_col, so it matches the orb. i3lock's own ring sits
        // underneath (used only for detection — it can never go green) and is fully
        // covered by this. Solid colour from the orb edge outward, anti-aliased at
        // the outer edge, carrying the same scanline + sweep + pulse as the orb.
        vec3 rcol = state_col * pulse;
        float scl = sin(texcoord.y * 0.7) * 0.5 + 0.5;
        rcol *= 1.0 - scl * 0.12;
        vec4 ringpx = apply_flash_effect(vec4(rcol, 1.0), texcoord);
        float edge = 1.0 - smoothstep(ring_outer - 2.0, ring_outer, dist); // outer AA
        vec4 bg = crt_shader(texcoord);
        bg.w = 1.0;
        bg = calc_opacity(bg, texcoord);
        c = vec4(mix(bg.rgb, ringpx.rgb, edge), 1.0);
    }

    vec4 fc = default_post_processing(c);
    fc.w = 1.0;   // force opaque — no desktop bleed through the padding
    return fc;
}
