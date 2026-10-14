# Investigation & Technical Analysis: Procedural Character, Fishing Rod Math & State Machine Design

- **Author**: Explorer 2 (`explorer_r2_2`)
- **Working Directory**: `c:\Users\Dibya\StudioProjects\monsoon_catch\.agents\teamwork\explorer_r2_2`
- **Target Milestone**: R2 — Procedural Character, Rod & Physics-Aware Fishing Line
- **Timestamp**: 2026-10-14T18:55:00Z

---

## Executive Summary

This investigation specifies the complete architectural, mathematical, and rendering design for the procedural character, fishing rod curvature, and state machine in *Monsoon Catch* for the fixed 640x360 virtual resolution viewport.

Key outcomes:
1. **Procedural Canvas Rendering**: A zero-bitmap, 100% Flutter Canvas rendered pixel-art character (fisherman with conical straw rain hat, cozy poncho/raincoat, articulated arms, mud boots, and wooden tackle seat) using vector paths, polygons, and rounded rects with pixel-aligned coordinates.
2. **Four Expressive Poses**:
   - `idle`: Relaxed upright stance with gentle breathing bob, holding rod at ~45° upward angle.
   - `casting`: Dynamic 4-phase whip arc along normalized progress $t \in [0, 1]$ (windup, power stroke, tip snap/release, follow-through).
   - `reeling` / `strain`: Braced-back pose against heavy fish pull, rod flexed into a deep parabolic arc downward toward the water, reel cranking cycle, and high-frequency tension vibration micro-jitter.
   - `caught`: Celebratory pose, chest puffed, rod held high (78°), displaying the caught fish with radiating pixel sparkles.
3. **Cubic Bezier Rod Curvature Math**: Physical beam-deflection model representing a tapered rod (stiff butt, flexible tip) using cubic Bezier control points $P_0, P_1, P_2, P_3$.
4. **Analytical Tip Coordinates**: Exact closed-form formulas for $P_{\text{tip}} = (x, y)$ in all 4 states and across animation progress $t$, guaranteeing that the fishing line origin $P_{\text{line\_start}} \equiv P_{\text{tip}}$ with zero floating or misalignment.
5. **State Machine & Transition API**: Clean, decoupled, testable pure Dart controller architecture with explicit transition graph, easing curves, timing parameters, and zero-artifact reset hooks.

---

## 1. Procedural Character Design & Cozy Pixel-Art Canvas Geometry

### 1.1 Resolution & Aesthetic Constraints
- **Target Resolution**: Fixed 640x360 virtual viewport.
- **Aesthetic**: Cozy, rainy monsoon pixel-art.
- **Rendering Mechanism**: Pure Flutter `Canvas` primitives (`drawRect`, `drawRRect`, `drawPath`, `drawLine`, `drawCircle`, `drawOval`).
- **Bitmap Constraint**: ZERO external `.png`, `.jpg`, or spritesheet assets. Eliminates file loading errors, asset bundle dependencies, and blurry scaling.

### 1.2 Color Palette Specification
A cohesive palette harmonizing with the dynamic weather system (Dawn, Day, Overcast, Monsoon):

| Element | Color Name | Hex Code | Purpose |
|---|---|---|---|
| **Straw Hat / Kasa** | Golden Bamboo | `0xFFD4A373` | Main conical hat surface |
| | Sun Straw Highlight | `0xFFFAEDCD` | Top edge / rain reflection rim |
| | Hat Shadow | `0xFFB07D4F` | Underside depth & brim shade |
| | Hat Ribbon / Band | `0xFF582F0E` | Contrast cinch band above brim |
| **Face & Skin** | Cozy Peach | `0xFFFFD1A9` | Exposed face, ears, hands |
| | Warm Shadow | `0xFFE0A97E` | Chin shadow, neck |
| | Eye / Features | Deep Ink Charcoal | `0xFF1E1E24` | 2x2 px eyes, calm expression |
| | Cheek Blush | Soft Rose | `0xFFF4A261` | Cozy warm blush dot |
| **Rain Poncho / Coat** | Deep Forest Teal | `0xFF2A9D8F` | Waterproof poncho body |
| | Poncho Shadow / Fold | Abyssal Navy Teal | `0xFF1E6056` | Underarm and rear drape fold |
| | Scarf / Collar Accent | Warm Saffron | `0xFFE76F51` | Cozy neck scarf peeking out |
| **Trousers & Boots** | Peat Slate Pants | `0xFF3D405B` | Fisherman durable trousers |
| | Mud Wader Boots | Deep Espresso Leather | `0xFF2B2D42` | Waterproof boots grounded on bank |
| | Boot Soles | Dark Mud | `0xFF1B1C29` | Bottom tread anchored to turf |
| **Tackle Box / Seat** | Polished Cedar | `0xFF8C5835` | Wooden crate character sits/perches on |
| | Cedar Highlight | `0xFFA06D44` | Top rim reflection |
| | Brass Corners / Clasp | Vintage Brass | `0xFFE9C46A` | Metal fittings |
| **Fishing Rod** | Bamboo / Graphite Blank| `0xFFC59B27` | Main rod shaft |
| | Rod Guide Rings | Silver Stainless | `0xFFCBD5E1` | Line guide loops |
| | Cork Handle Grip | Natural Cork | `0xFFDDB892` | Hand grip at rod butt |
| | Reel Body & Spool | Gunmetal Chrome | `0xFF475569` | Spinning reel attached near butt |

### 1.3 Canvas Geometry & Component Dimensions
- **World Ground Level**: On the riverbank platform, the flat grassy turf sits at $y_{\text{ground}} = 208.8\text{ px}$ (spanning $x = 0$ to $x \approx 133.12\text{ px}$).
- **Canonical Ground Anchor Point**: $(x_{\text{ground}}, y_{\text{ground}}) = (116.0, 208.0)$.
- **Character Bounding Box**: $W_{\text{char}} = 36\text{ px}$, $H_{\text{char}} = 44\text{ px}$ (footprint $x \in [98, 134]$, $y \in [164, 208]$).
- **Rod Bounding Reach**: Extends up to $x \approx 190.0$ and up to $y \approx 125.0$ depending on pose.

```
       [Top of Hat (y=164)]
             /\  <-- Conical Straw Hat (W=32, H=10)
            /__\ 
           ( o.o) <-- Head (12x10) + Peach Skin + Scarf (y=174)
          /|====|\ <-- Poncho / Torso (W=20, H=16) (y=184)
         / |====| \ 
        [Hand (132, 186)] ===[CORK GRIP]===> ROD BLANK ===> TIP
           | || |  <-- Pants / Wader Legs (y=200)
          [==][==] <-- Rubber Mud Boots (y=206..208)
   ~~~~~~~~~~~~~~~~~ RIVERBANK TURF PLATFORM (y=208.0) ~~~~~~~~~~~~~~~~~
```

### 1.4 Vector Path Primitives
1. **Conical Straw Hat (`_hatPath`)**:
   - Crown Peak: $(x_c, y_{\text{head}} - 4)$
   - Left Brim: $(x_c - 16, y_{\text{head}} + 4)$
   - Right Brim: $(x_c + 16, y_{\text{head}} + 4)$
   - Underside Brim Arc: `quadraticBezierTo(x_c, y_{\text{head}} + 6, x_c + 16, y_{\text{head}} + 4)`
   - Ribbon Band: Horizontal strip of height 2 px across the lower third of the cone.
2. **Head & Face (`_headRRect`)**:
   - `RRect.fromRectAndRadius(Rect.fromLTWH(x_c - 5, y_{\text{head}}, 10, 10), Radius.circular(3))`
   - Eyes: Two 2x2 pixel rects at $(x_c + 1, y_{\text{head}} + 4)$ and $(x_c + 4, y_{\text{head}} + 4)$ facing right towards water.
   - Blush: Soft rose 2x1 rect at $(x_c + 3, y_{\text{head}} + 7)$.
3. **Poncho / Raincoat (`_ponchoPath`)**:
   - Scarf/Collar: 12x4 rounded polygon at $(x_c - 6, y_{\text{head}} + 8)$.
   - Trapezoidal body expanding from shoulders (width 14) to hem (width 22):
     `moveTo(x_c - 7, y_{\text{torso}})` -> `lineTo(x_c + 7, y_{\text{torso}})` -> `lineTo(x_c + 11, y_{\text{torso}} + 16)` -> `lineTo(x_c - 11, y_{\text{torso}} + 16)` -> `close()`.
4. **Legs & Boots**:
   - Left Leg: Rect $(x_c - 7, y_{\text{ground}} - 8, 6, 8)$
   - Right Leg: Rect $(x_c + 1, y_{\text{ground}} - 8, 6, 8)$
   - Boot Soles: Rounded caps extending 2 px forward for stability.
5. **Arms & Hands**:
   - Articulated 2-segment arm path: Shoulder $(x_s, y_s) \to$ Elbow $(x_e, y_e) \to$ Hand $(x_h, y_h)$.
   - Hand coordinates directly establish the rod butt anchor $P_0$.

---

## 2. Four Expressive Character States & Body Kinematics

### 2.1 State Matrix Overview

| State | Emotional Dynamic | Torso Lean | Hand Grip $P_0$ | Rod Angle $\theta_{\text{base}}$ | Rod Flex Behavior | Tip Pos $P_{\text{tip}}$ |
|---|---|---|---|---|---|---|
| **`idle`** | Serene, patient, breathing | $0^\circ$ (upright) | $(132.0, 186.0)$ | $+45.0^\circ$ | Nearly straight, slight $2.5\text{ px}$ gravity sag | $(167.7, 153.9)$ |
| **`casting`** ($t \in [0, 1]$) | Athletic, whip stroke | $-8^\circ \to +18^\circ$ | $(122 \dots 144, 176 \dots 182)$ | $130^\circ \to 20^\circ$ | Inertial dynamic whip arc (lags behind hand) | Sweeps $x: 91 \to 189$ |
| **`reeling` / `strain`** | Heavy struggle, bracing | $-18^\circ$ (braced back) | $(124.0, 184.0)$ | $+38.0^\circ$ | Deep parabolic bow downward + high-freq jitter | $(164.6, 192.6)$ |
| **`caught`** | Triumphant celebration | $+5^\circ$ (proud hop) | $(128.0, 172.0)$ | $+78.0^\circ$ | Stiff high rod, dangling fish on leader line | $(138.0, 125.1)$ |

---

### 2.2 Detailed Kinematics by State

#### 1. `idle`
- **Pose**: The fisherman stands (or sits perched) comfortably on the grassy riverbank.
- **Micro-animation**: Subtle sinusoidal vertical bobbing:
  $$y_{\text{bob}}(t) = 0.8 \cdot \sin\left(\frac{2\pi t}{2.4}\right)\text{ px}$$
- **Hands**: Gripping rod at waist height:
  $$P_0 = (132.0, 186.0 + y_{\text{bob}})$$
- **Rod Angle**: Angled upward at $\theta_0 = 45.0^\circ$ towards the pond.
- **Details**: Calm eye glint; rain droplets occasionally slide off the front tip of the straw hat.

#### 2. `casting`
A cinematic 4-phase casting animation parameterized by $t \in [0.0, 1.0]$ over duration $T_{\text{cast}} = 0.65\text{ s}$:
- **Phase 1: Back-cast Windup ($t \in [0.00, 0.25]$)**:
  - Sub-progress: $\tau_1 = t / 0.25 \in [0, 1]$.
  - Torso leans backward by $8^\circ$.
  - Hand raises upward and backward:
    $$P_0(\tau_1) = (132.0 - 10.0 \tau_1, 186.0 - 10.0 \tau_1)$$
  - Rod rotates clockwise to overhead back-cast angle:
    $$\theta(\tau_1) = 45^\circ + 85^\circ \cdot S(\tau_1) \quad (\text{reaching } 130^\circ)$$
    where $S(\tau) = 3\tau^2 - 2\tau^3$ (smoothstep).
  - Tip lags forward due to initial backward acceleration.
- **Phase 2: Forward Power Whip ($t \in [0.25, 0.65]$)**:
  - Sub-progress: $\tau_2 = (t - 0.25) / 0.40 \in [0, 1]$.
  - Torso lunges forward by $+18^\circ$, knee flexes forward.
  - Hand accelerates forward:
    $$P_0(\tau_2) = (122.0 + 22.0 \tau_2, 176.0 + 6.0 \tau_2)$$
  - Rod base whips forward from $130^\circ$ down to $20^\circ$:
    $$\theta(\tau_2) = 130^\circ - 110^\circ \cdot \tau_2^2$$
  - **Inertial Bend**: The rod experiences extreme dynamic flex! The tip lags heavily behind the base:
    $$\Delta \theta_{\text{lag}}(\tau_2) = 46^\circ \cdot \sin(\pi \tau_2)$$
    This creates an elastic, whipping C-curve.
- **Phase 3: Tip Snap & Release ($t \in [0.65, 0.85]$)**:
  - Sub-progress: $\tau_3 = (t - 0.65) / 0.20 \in [0, 1]$.
  - Hand holds firm at $P_0 = (144.0, 182.0)$.
  - The elastic energy stored in the rod blanks releases violently: the tip snaps forward and overshoots:
    $$\Delta \theta_{\text{snap}}(\tau_3) = -12^\circ \cdot (1 - \tau_3) \cdot \cos(3\pi \tau_3)$$
  - This marks the exact moment the bobber is launched into the water!
- **Phase 4: Settle & Dampened Recovery ($t \in [0.85, 1.00]$)**:
  - Sub-progress: $\tau_4 = (t - 0.85) / 0.15 \in [0, 1]$.
  - Character smoothly eases back from lunge to idle stance ($P_0 \to (132.0, 186.0)$).
  - Rod angle gently settles back from $25^\circ$ to $45^\circ$.

#### 3. `reeling` / `strain`
- **Pose**: A heavy monsoon fish has struck the bait! The character braces backward to resist the pull.
- **Torso & Legs**: Body leans back by $-18^\circ$ (away from the water), front boot digs into the turf rim, knees bent low for leverage.
- **Facial Expression**: Determined, teeth clenched / mouth set, eyebrows furrowed downward, tension sweat droplet.
- **Hands**:
  - Right hand pulls rod butt firmly inward: $P_0 = (124.0, 184.0)$.
  - Left hand rapidly rotates the reel handle in a circular crank orbit:
    $$P_{\text{crank}}(\tau) = P_0 + (4.0, 2.0) + 3.0 \cdot (\cos(8\pi t), \sin(8\pi t))$$
- **Rod Flex**: Parabolic bow under heavy tension. Tip is pulled down into the water plane ($y \approx 192.6$).
- **Tension Micro-Jitter (Line Hum)**:
  High-frequency flutter simulating line strum under extreme tension:
  $$\delta_{\text{jitter}}(t) = 1.2 \cdot \sin(32\pi t)\text{ px}$$

#### 4. `caught`
- **Pose**: Triumphant catch! The fish is reeled in.
- **Body**: Character stands tall, jumping slightly off the turf in celebration:
  $$y_{\text{hop}}(t) = -3.5 \cdot |\sin(4\pi t)|\text{ px}$$
- **Facial Expression**: Wide happy smile (`^ _ ^`), rosy cheeks, eyes crinkled in delight.
- **Arms**:
  - Right arm raises the rod high overhead at $\theta = 78^\circ$, displaying the catch proudly:
    $$P_0 = (128.0, 172.0 + y_{\text{hop}})$$
  - Left arm is raised holding the fish or pointing to it.
- **Catch Display**:
  - A procedural pixel-art fish (length $14\text{ px}$, height $8\text{ px}$, emerald/silver scales, wiggling tail fin) dangles from a short leader line attached to $P_{\text{tip}}$.
  - Radiant star sparkles (`+` and `*` in gold `0xFFFFD166` and seafoam `0xFF06D6A0`) expand outward for $1.0\text{ s}$.

---

## 3. Mathematical Rod Curvature Formulation

### 3.1 Physical Foundation: Tapered Cantilever Beam
A fishing rod is not a uniform beam; it is a tapered hollow blank where the outer diameter $D(s)$ decreases from butt ($s = 0$) to tip ($s = 1$):
$$D(s) = D_0 \left(1 - \lambda s\right), \quad \lambda \approx 0.65$$
The area moment of inertia $I(s) \propto D(s)^4$. Consequently, flexural rigidity $EI(s)$ drops by over 85% from butt to tip:
$$\frac{EI(1)}{EI(0)} \approx (1 - 0.65)^4 = 0.015$$
When tension $T$ acts on the rod tip, the bending curvature $\kappa(s) = \frac{M(s)}{EI(s)}$ concentrates predominantly in the upper half ($s \in [0.5, 1.0]$), while the lower butt section ($s \in [0.0, 0.4]$) remains stiff and closely aligned with the grip angle $\theta_{\text{base}}$.

### 3.2 Cubic Bezier Formulation
We model the rod curve $B(s), s \in [0, 1]$ using a cubic Bezier curve with 4 control points:
$$\mathbf{B}(s) = (1-s)^3 \mathbf{P}_0 + 3(1-s)^2 s \mathbf{P}_1 + 3(1-s)s^2 \mathbf{P}_2 + s^3 \mathbf{P}_3, \quad s \in [0, 1]$$
- $\mathbf{P}_0 = (x_0, y_0)$: Rod butt anchored at the character's hand.
- $\mathbf{P}_1$: Tangent guide preserving butt stiffness. Lies strictly along the grip direction vector $\hat{\mathbf{u}}_{\text{grip}} = (\cos \theta, -\sin \theta)$:
  $$\mathbf{P}_1 = \mathbf{P}_0 + c_1 L \cdot \hat{\mathbf{u}}_{\text{grip}}, \quad c_1 = 0.35$$
- $\mathbf{P}_2$: Mid-rod flex transition control point, deflected by the external tension load vector $\vec{\mathbf{F}}_{\text{load}}$:
  $$\mathbf{P}_2 = \mathbf{P}_0 + c_2 L \cdot \hat{\mathbf{u}}_{\text{grip}} + \vec{\mathbf{D}}_{\text{flex}}, \quad c_2 = 0.70$$
- $\mathbf{P}_3 = \mathbf{P}_{\text{tip}}$: The physical rod tip where the fishing line attaches!
  $$\mathbf{P}_3 \equiv \mathbf{B}(1)$$

---

## 4. Analytical Rod Tip Coordinates $(x_{\text{tip}}, y_{\text{tip}})$ & Zero-Misalignment Derivation

### 4.1 Proof of Zero Floating / Zero Misalignment
In naive implementations, rod rendering and fishing line rendering compute their coordinates independently, leading to 1-3 pixel gaps ("floating line") during animations.

**Theorem (Zero-Gap Guarantee)**:
Let the rod curve be $\mathbf{B}(s)$ with tip $\mathbf{P}_{\text{tip}} = \mathbf{B}(1)$.
Let the fishing line start point be defined as:
$$\mathbf{P}_{\text{line\_start}} \equiv \mathbf{B}(1)$$
Then the Euclidean distance between rod tip and line start is:
$$\|\mathbf{P}_{\text{line\_start}} - \mathbf{P}_{\text{tip}}\| = \|\mathbf{B}(1) - \mathbf{B}(1)\| \equiv 0.0000000000$$
By exposing $\mathbf{P}_{\text{tip}}$ as a shared vector computed synchronously in the same frame tick, floating or detached line artifacts are mathematically impossible across all states and viewport scales.

---

### 4.2 Exact Analytical Tip Coordinates for All States

Let nominal rod length be $L = 48.0\text{ px}$.

#### State 1: `idle`
- $P_0 = (132.0, 186.0)$
- Grip angle: $\theta_{\text{grip}} = 45.0^\circ = 0.7854\text{ rad}$
- Direction vector: $\hat{u} = (\cos 45^\circ, -\sin 45^\circ) = (0.707107, -0.707107)$
- Natural gravity tip deflection: $\Delta \theta = 3.0^\circ \implies \theta_{\text{tip}} = 42.0^\circ$
- Chord length: $L_{\text{chord}} = 48.0\text{ px}$
- **Control Points**:
  - $P_0 = (132.0, 186.0)$
  - $P_1 = (132.0, 186.0) + 0.35(48.0)(0.7071, -0.7071) = (143.88, 174.12)$
  - $P_2 = (132.0, 186.0) + 0.70(48.0)(0.7071, -0.7071) + (0.0, 1.2) = (155.76, 163.44)$
  - $P_3 = P_{\text{tip}} = (132.0 + 48.0 \cos 42^\circ, 186.0 - 48.0 \sin 42^\circ)$
- **Analytical Value**:
  $$x_{\text{tip}}^{\text{idle}} = 132.0 + 48.0 \times 0.743145 = \mathbf{167.671}\text{ px}$$
  $$y_{\text{tip}}^{\text{idle}} = 186.0 - 48.0 \times 0.669131 = \mathbf{153.882}\text{ px}$$

#### State 2: `casting` ($t \in [0, 1]$)
Expressed as a continuous parametric vector function of progress $t$:

$$\mathbf{P}_{\text{tip}}(t) = \mathbf{P}_0(t) + L_{\text{chord}}(t) \begin{pmatrix} \cos \theta_{\text{tip}}(t) \\ -\sin \theta_{\text{tip}}(t) \end{pmatrix}$$

Where:
1. **At Windup Apex ($t = 0.25$)**:
   - $P_0 = (122.0, 176.0)$
   - $\theta = 130.0^\circ$
   - $\hat{u} = (\cos 130^\circ, -\sin 130^\circ) = (-0.642788, -0.766044)$
   - $$x_{\text{tip}}(0.25) = 122.0 + 48.0(-0.642788) = \mathbf{91.146}\text{ px}$$
   - $$y_{\text{tip}}(0.25) = 176.0 - 48.0(0.766044) = \mathbf{139.230}\text{ px}$$

2. **At Mid-Power Whip ($t = 0.45$)**:
   - $P_0 = (133.0, 179.0)$
   - Base angle $\theta_{\text{base}} = 65^\circ$, tip lags at $\theta_{\text{tip}} = 104^\circ$
   - Due to extreme C-bend, chord contracts to $L_{\text{chord}} = 42.5\text{ px}$
   - $$x_{\text{tip}}(0.45) = 133.0 + 42.5 \cos 104^\circ = 133.0 + 42.5(-0.24192) = \mathbf{122.718}\text{ px}$$
   - $$y_{\text{tip}}(0.45) = 179.0 - 42.5 \sin 104^\circ = 179.0 - 42.5(0.97030) = \mathbf{137.762}\text{ px}$$

3. **At Release Flick ($t = 0.65$)**:
   - $P_0 = (144.0, 182.0)$
   - Forward sweep $\theta_{\text{tip}} = 20.0^\circ$, fully extended $L_{\text{chord}} = 48.0\text{ px}$
   - $$x_{\text{tip}}(0.65) = 144.0 + 48.0 \cos 20^\circ = 144.0 + 48.0(0.939693) = \mathbf{189.105}\text{ px}$$
   - $$y_{\text{tip}}(0.65) = 182.0 - 48.0 \sin 20^\circ = 182.0 - 48.0(0.342020) = \mathbf{165.583}\text{ px}$$

#### State 3: `reeling` / `strain`
Under heavy fish tension pulling downward toward the water line ($y \approx 234$):
- Grip anchor: $P_0 = (124.0, 184.0)$
- Grip angle: $\theta_{\text{grip}} = 38.0^\circ$
- Heavy bend deflection: Tip flexes down by $\Delta \theta = 50.0^\circ \implies \theta_{\text{tip}} = -12.0^\circ$ (pointing downward into the pond!).
- Chord foreshortening under strain: $L_{\text{chord}} = 41.5\text{ px}$ ($\eta = 0.865$).
- **Control Points**:
  - $P_0 = (124.0, 184.0)$
  - $P_1 = (124.0, 184.0) + 0.35(48.0)(\cos 38^\circ, -\sin 38^\circ) = (137.24, 173.66)$
  - $P_2 = (148.50, 180.20)$
  - $P_3 = P_{\text{tip}}$
- **Analytical Steady-State Value**:
  $$x_{\text{tip}}^{\text{strain}} = 124.0 + 41.5 \cos(-12^\circ) = 124.0 + 41.5(0.978148) = \mathbf{164.593}\text{ px}$$
  $$y_{\text{tip}}^{\text{strain}} = 184.0 - 41.5 \sin(-12^\circ) = 184.0 + 41.5(0.207912) = \mathbf{192.628}\text{ px}$$
- **With Tension Micro-Jitter ($f = 14\text{ Hz}$)**:
  $$x_{\text{tip}}^{\text{strain}}(t) = 164.593 + 0.6 \sin(28\pi t)\text{ px}$$
  $$y_{\text{tip}}^{\text{strain}}(t) = 192.628 + 1.2 \sin(28\pi t + \pi/4)\text{ px}$$
  *(Notice the tip drops by $38.75\text{ px}$ relative to idle, visually demonstrating the immense drag of the hooked fish!)*

#### State 4: `caught`
- Grip anchor: $P_0 = (128.0, 172.0)$
- Rod angle: $\theta = 78.0^\circ$ (held high overhead)
- Light dangling weight bend: $\Delta \theta = 4.0^\circ \implies \theta_{\text{tip}} = 74.0^\circ$
- $L_{\text{chord}} = 48.0\text{ px}$
- **Control Points**:
  - $P_0 = (128.0, 172.0)$
  - $P_1 = (128.0, 172.0) + 0.35(48.0)(\cos 78^\circ, -\sin 78^\circ) = (131.49, 155.57)$
  - $P_2 = (135.00, 139.15)$
  - $P_3 = P_{\text{tip}}$
- **Analytical Value**:
  $$x_{\text{tip}}^{\text{caught}} = 128.0 + 48.0 \cos 74^\circ = 128.0 + 48.0(0.275637) = \mathbf{141.231}\text{ px}$$
  $$y_{\text{tip}}^{\text{caught}} = 172.0 - 48.0 \sin 74^\circ = 172.0 - 48.0(0.961262) = \mathbf{125.859}\text{ px}$$
  *(Tip is elevated to $y = 125.86$, towering $28\text{ px}$ above the idle tip in celebration).*

---

## 5. State Machine Architecture, Transition Graph & API

### 5.1 State Machine Transition Graph

```
           [ TAP WATER ]
      +--------------------> [ CASTING ]
      |                          |
      |                          | (t = 1.0, Bobber Lands)
      |                          v
  [ IDLE ] <================== [ IDLE / FLOATING ]
      ^                          |
      |                          | (Fish Bites / Reeling)
      |                          v
      |                   [ REELING / STRAIN ]
      |                          |            \
      | (Dismiss / Timeout)      | (Hook!)     \ (Miss / Early Pull)
      |                          v              v
      +------------------ [ CAUGHT ]       [ RESET / RETRACT ]
                                                |
                                                +---> (Immediately back to IDLE)
```

### 5.2 Transition Rules & Invariants
1. `idle -> casting`: Triggered when player taps valid water zone ($x \ge 192$, $y \ge 220$). Cast timer starts at $t = 0.0$.
2. `casting -> idle`: Completes automatically when cast timer reaches $1.0$. Bobber is placed at destination. Line settles.
3. `idle -> reeling`: Triggered when fish strikes or player initiates reeling during bite window.
4. `reeling -> caught`: Triggered when player taps during valid bite window. Sparks trigger, fish appears.
5. `reeling -> reset`: Triggered on miss or early reel. Retraction hook executes immediately.
6. `caught -> idle`: Celebratory state lasts $2.0\text{ s}$ or until next tap, then cleanly transitions to `idle`.

### 5.3 Controller Interface Specification (`ProceduralCharacterController`)
The character component should be driven by a clean, pure-Dart controller:

```dart
enum CharacterPoseState {
  idle,
  casting,
  reeling,
  caught,
}

abstract class CharacterPoseController {
  CharacterPoseState get state;
  double get animationProgress; // t in [0.0, 1.0]
  Vector2 get rodBasePosition;  // P0 in world coords
  Vector2 get rodTipPosition;   // P3 in world coords
  List<Vector2> get rodControlPoints; // [P0, P1, P2, P3]

  void startCast(Vector2 targetWaterPos, {VoidCallback? onComplete});
  void startStrain();
  void triggerCatch({VoidCallback? onComplete});
  void resetToIdle();
  void update(double dt);
}
```

### 5.4 Immediate Clean Retraction & Reset Hook
When a catch completes, a bite is missed, or a cast is aborted:
- `resetToIdle()`:
  1. Instantly sets `state = CharacterPoseState.idle`.
  2. Cancels any active cast or strain tickers/tweens.
  3. Resets $t = 0.0$.
  4. Signals `FishingLineComponent` to deactivate: `isLineVisible = false`.
  5. Signals `BobberComponent` to deactivate: `isBobberVisible = false`.
  6. Zero heap allocations, zero lingering canvas draw calls, zero ghost line artifacts.

---

## 6. Procedural Component Implementation Blueprint

Below is the concrete design for `ProceduralCharacterComponent` replacing `CharacterPlaceholder`:

```dart
class ProceduralCharacterComponent extends PositionComponent {
  final WeatherState weather;
  CharacterPoseState poseState = CharacterPoseState.idle;
  double _stateTime = 0.0;
  double _castProgress = 0.0;

  // Cached vector paths to eliminate per-frame allocations
  final Path _hatPath = Path();
  final Path _ponchoPath = Path();
  final Path _rodPath = Path();

  // Cached reusable Paint objects
  final Paint _hatPaint = Paint()..color = const Color(0xFFD4A373);
  final Paint _ponchoPaint = Paint()..color = const Color(0xFF2A9D8F);
  final Paint _skinPaint = Paint()..color = const Color(0xFFFFD1A9);
  final Paint _rodPaint = Paint()
    ..color = const Color(0xFFC59B27)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;

  ProceduralCharacterComponent({
    required Vector2 position,
    required this.weather,
  }) : super(
         position: position,
         size: Vector2(80, 80),
         anchor: Anchor.bottomLeft,
         priority: GameConfig.priorityCharacter,
       );

  /// Analytical rod tip position in world coordinates (640x360 space)
  Vector2 get rodTipPosition => position + _computeLocalRodTip();

  Vector2 _computeLocalRodTip() {
    switch (poseState) {
      case CharacterPoseState.idle:
        return Vector2(51.67, -54.12); // relative to bottom-left anchor
      case CharacterPoseState.casting:
        return _interpolateCastTip(_castProgress);
      case CharacterPoseState.reeling:
        final jitter = 1.2 * sin(28 * pi * _stateTime);
        return Vector2(48.59, -15.37 + jitter);
      case CharacterPoseState.caught:
        return Vector2(25.23, -82.14);
    }
  }

  @override
  void render(Canvas canvas) {
    // 1. Render Seat / Tackle Box
    _renderSeat(canvas);
    // 2. Render Character Body (Boots, Poncho, Head, Straw Hat)
    _renderBody(canvas);
    // 3. Render Procedural Rod Bezier Curve
    _renderRod(canvas);
    // 4. If caught, render caught fish & celebration sparkles
    if (poseState == CharacterPoseState.caught) {
      _renderCelebration(canvas);
    }
  }
}
```

---

## 7. Verification Strategy & Test Matrix

To guarantee mathematical precision and robust stability, the following unit and integration tests must be written:

| Test Case | Description | Expected Assertion |
|---|---|---|
| **`testRodTipIdle`** | Evaluate rod tip at idle | $(x, y) \approx (167.67, 153.88) \pm 0.1$ |
| **`testRodTipStrain`** | Evaluate rod tip at strain state | Downward deflection $\ge 35\text{ px}$ relative to idle |
| **`testRodTipCaught`** | Evaluate rod tip at caught state | Upward elevation $\ge 25\text{ px}$ relative to idle |
| **`testCastContinuity`** | Sample $t \in [0, 1]$ at 100 intervals | $P_{\text{tip}}(t)$ is $C^0$ continuous with no NaN or jump discontinuities |
| **`testZeroFloatingGap`** | Compare rod tip to line start | $\|P_{\text{tip}} - P_{\text{line\_start}}\| == 0.0$ strictly |
| **`testResetCleanup`** | Call `resetToIdle()` in every state | Immediately transitions to idle, clears line/bobber active flags |
| **`testProceduralIndependence`**| Verify no asset loaders in character | Component initializes with zero network or filesystem assets |
