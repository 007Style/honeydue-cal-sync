# vertexWorld — Full Design Document

> **Version:** 0.1.0 — Initial Design Spec  
> **Genre:** 3D Open-World Exploration / Building / Survival  
> **Engine:** Three.js (WebGL) + Vite  
> **Platform:** Web Browser (Desktop)

---

## 1. Vision Statement

vertexWorld is a browser-based 3D exploration and building game set across an infinite multiverse of procedurally generated spherical planets. The player begins on a starter world and can — at any moment — look up at the sky, target one of the glowing planets orbiting above, charge up a launch, and hurl themselves through space to land on an entirely new world with its own biomes, creatures, resources, and secrets.

The core pillars are:
- **Exploration** — Every planet is unique. No two worlds are the same.
- **Building** — Dig, collect, and construct anything you can imagine on any world.
- **Survival** — Creatures roam the worlds. Some are passive. Some will hunt you. Bosses guard the greatest secrets.
- **Wonder** — The sky is never empty. There is always somewhere new to go.

---

## 2. World Architecture

### 2.1 Spherical Planets

Each world is a sphere. Terrain is generated on the surface of the sphere using 3D simplex noise mapped onto a subdivided icosphere. Gravity always points toward the planet's core, so the player can walk all the way around the globe.

- **Radius range:** 200–800 blocks per planet
- **Surface blocks:** ~4–6 layers deep before hitting core rock
- **Core:** Indestructible bedrock at the planet center
- **Atmosphere:** Each planet has a sky color, fog density, and ambient light color

### 2.2 Multi-Planet Solar System

At any time, 4–8 other planets are visible in the sky above the player. They are rendered as distant glowing spheres with slight atmospheric glow halos. They slowly rotate and drift, giving the sky a living feel.

- Planets range from tiny asteroid-sized rocks to large continent-covered worlds
- Some planets have visible ring systems (purely decorative from a distance)
- Some planets appear volcanic with an orange glow
- Some planets appear icy blue
- One special **Dark Planet** is always visible — pitch black with faint purple veins — home to the Void Dragon boss

### 2.3 Biomes

Each planet surface is divided into biome regions determined by noise and latitude:

| Biome | Description | Unique Features |
|---|---|---|
| Grasslands | Rolling green hills | Flowers, sheep, deer, bunnies, oak trees |
| Forest | Dense tree cover | Wolves, eagles, mushrooms, hidden caves |
| Desert | Sandy dunes | Lizards, scorpions, buried ruins, cacti |
| Tundra | Snow-covered plains | Polar bears, ice wolves, frozen lakes |
| Volcanic | Lava fields, ash | Dragons, fire salamanders, obsidian spires |
| Ocean | Water covering surface | Fish, sharks, sea turtles, coral reefs |
| Swamp | Murky shallow water | Crocodiles, frogs, fireflies at night |
| Crystal Caves | Underground only | Crystal formations, cave trolls, glowing worms |
| Mushroom Fields | Giant mushrooms | Passive spore creatures, no hostile mobs spawn |
| Ruins | Ancient stone structures | Skeleton warriors, treasure chests, lore tablets |

### 2.4 Terrain Features

- **Trees** — Oak, Pine, Palm, Giant Mushroom, Crystal Tree (alien worlds)
- **Rivers** — Flow downhill using fluid simulation approximation, empty into oceans
- **Mountains** — Tall peaks with snow caps above a certain altitude
- **Caves** — Underground tunnel networks with ores, crystals, and spawned creatures
- **Ruins** — Crumbled stone structures with loot chests and inscribed lore tablets
- **Volcanoes** — Active volcanoes that periodically eject lava blocks
- **Floating Islands** — Rare small landmasses floating above the planet surface, reachable by building or jumping
- **Meteor Craters** — Impact craters filled with rare meteor ore
- **Underground Lakes** — Hidden water bodies underground, often with bioluminescent fish

---

## 3. Block System

### 3.1 Block Types

| Block | Properties | Found In |
|---|---|---|
| Grass | Diggable, drops dirt | Surface — Grasslands |
| Dirt | Diggable | Subsurface |
| Stone | Hard, requires pickaxe | Underground |
| Sand | Falls with gravity | Desert, Beaches |
| Snow | Soft, slides | Tundra |
| Wood | Diggable by hand | Trees |
| Leaves | Decays without wood | Trees |
| Water | Fluid, flows | Oceans, Rivers |
| Lava | Damages player | Volcanic |
| Obsidian | Very hard | Volcanic, Lava-water borders |
| Coal Ore | Mineable resource | Underground |
| Iron Ore | Mineable resource | Deep underground |
| Gold Ore | Rare resource | Deep underground |
| Crystal Ore | Alien worlds only | Crystal Caves |
| Meteor Ore | Very rare | Meteor Craters |
| Bedrock | Indestructible | Planet core |
| Glass | Crafted from sand | Player crafted |
| Torch | Placed light source | Player crafted |
| Ladder | Climbable | Player crafted |
| Chest | Storage container | Player crafted / Found in ruins |

### 3.2 Block Physics
- Sand and gravel fall when unsupported
- Water flows to fill lower spaces (simplified cellular automaton)
- Lava flows slowly and damages the player on contact
- Torches provide local lighting radius

---

## 4. Creatures & AI

All creatures use a **Finite State Machine (FSM)** with the following base states:
- **Idle** — Standing still, playing idle animation
- **Wander** — Moving randomly within a territory radius
- **Flee** — Running away from a threat
- **Hunt** — Pursuing and attacking a target
- **Attack** — In melee/ranged attack range, dealing damage
- **Dead** — Playing death animation, then despawning and dropping loot

### 4.1 Passive Creatures

| Creature | Behavior | Loot | Special |
|---|---|---|---|
| Sheep | Wanders, flees on approach | Wool x2 | Can be sheered without killing |
| Deer | Wanders, very fast flee | Hide, Antler | Leaps over obstacles |
| Bunny | Hops erratically, very fast | Fur | Tiny, hard to hit |
| Cow | Slow wander, flees | Leather, Meat | Found near water |
| Pig | Slow wander | Meat | Wallows in mud near rivers |
| Fish | Swims in schools | Fish (food) | Ocean and rivers |
| Sea Turtle | Slow swim | Shell | Ocean, lays eggs on beaches |
| Frog | Hops, passive | Slime | Swamp |
| Parrot | Flies, passive | Feather | Forest canopy |
| Glowworm | Crawls, passive | Glowing Dust | Crystal Caves |

### 4.2 Hostile Creatures

| Creature | Behavior | Loot | Special |
|---|---|---|---|
| Wolf | Hunts in packs of 2–5 | Fang, Hide | Pack leader calls others when in combat |
| Crocodile | Ambushes near water | Hide, Tooth | Charges in a straight line burst |
| Eagle | Dives from above | Feather, Talon | Aerial attack, hard to hit |
| Cave Troll | Patrols underground | Stone Club, Troll Hide | Throws boulders, only spawns underground or at night |
| Desert Scorpion | Fast movement, poison sting | Stinger, Chitin | Poison status effect on player |
| Ice Wolf | Like wolf but faster, spawns in packs | Ice Fang | Howl slows player movement temporarily |
| Skeleton Warrior | Patrols ruins | Bone, Ancient Coin | Fires arrows, respawns in ruins unless chest is looted |
| Lava Salamander | Walks through lava | Fire Scale | Immune to lava, spits fire projectiles |
| Shadow Bat | Swarms at night | Bat Wing | Spawns in swarms of 10–20, weak individually |
| Shark | Patrols deep ocean | Shark Fin, Tooth | Charges at swimming player |

### 4.3 Boss Creatures

#### 🐲 The Dragon (Volcanic World Boss)
- **Found on:** Every planet's Volcanic biome — but only one per planet, and only if the volcano is active
- **Size:** 20x the size of the player
- **Behavior:**
  - Patrols the volcanic region, flying slow lazy circles
  - On player detection: swoops down, breathes a cone of fire
  - Phase 2 (below 50% health): lands, slams the ground causing shockwaves, summons Lava Salamanders
  - Phase 3 (below 20% health): flies erratically, charges full-speed dive bombs
- **Loot:** Dragon Scale (armor crafting), Dragon Heart (crafting material for Star Compass), Treasure Chest (contains rare ores and a lore tablet)
- **Special:** Killing a Dragon on any planet causes a visible "dead volcano" visual change on that planet — the sky above dims slightly and the volcano goes quiet

#### 👾 The Void Wraith (Space Transit Boss)
- **Found in:** Space — appears during planet-to-planet travel if the player takes too long or targets the Dark Planet
- **Size:** Enormous, fills the view during transit
- **Behavior:**
  - Materialises as a swirling dark mass of tentacles in space
  - Grabs the player mid-flight and begins draining health
  - Player must mash Left-Click to swing pickaxe and break free
  - If not broken free within 10 seconds, player is flung back to origin planet at 1 heart
- **Loot:** Void Shard (very rare — used for end-game crafting)
- **Special:** Becomes more frequent and aggressive as the player collects more Dragon Hearts

#### 🌑 The Dark Sovereign (Dark Planet Boss)
- **Found on:** The Dark Planet only
- **Description:** A massive humanoid figure made of obsidian and void energy, standing 40 blocks tall
- **Behavior:**
  - Summons Void Wraiths as minions
  - Stomps — shockwave damages and knocks back player
  - Void Ray — charges a beam attack, player must hide behind a block
  - Teleports randomly around the arena
- **Loot:** Sovereign Crown (cosmetic headpiece), Void Core (allows crafting of the Multiverse Beacon)
- **Unlock:** Defeating the Dark Sovereign triggers the end-game sequence — a cutscene showing all planets glowing and a new ring of distant galaxies becoming visible in the sky

---

## 5. Player Systems

### 5.1 Stats
- **Health:** 10 hearts (20 HP). Regenerates slowly when not in combat and stamina > 50%
- **Stamina:** 100 points. Used for sprinting, jumping, and charging planet launches. Regens when idle
- **Hunger:** (optional / future) Eating food restores health faster

### 5.2 Controls

| Action | Control |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Jump | Space |
| Sprint | Left Shift (hold) |
| Dig / Attack | Left Mouse Button |
| Place Block | Right Mouse Button |
| Open Inventory | E |
| Hotbar select | 1–9 / Scroll Wheel |
| Planet Launch Charge | Look at planet in sky → hold Space |
| Planet Launch Release | Release Space |
| Pause / Menu | Escape |

### 5.3 Planet Launch Mechanic
1. Player looks up and moves crosshair over a visible planet
2. Planet reticle appears — a glowing ring around the targeted planet
3. Player holds Space — a charge bar fills over 2 seconds with a whooshing sound
4. On release, the player is launched upward at high velocity toward the planet
5. During flight, the player can aim slightly left/right with the mouse
6. Atmosphere entry: screen briefly flashes white, a rumbling sound plays
7. Player lands on the surface of the destination planet
8. The original planet is now visible in the sky of the new world

### 5.4 Inventory
- 36 inventory slots in a 9x4 grid
- 9-slot hotbar at the bottom of the screen
- Items: Blocks, Tools, Weapons, Food, Crafting Materials, Quest Items
- Drag-and-drop interface
- Stack size: 64 for blocks, 1 for tools/weapons

### 5.5 Crafting
A simple crafting grid (3x3) accessible from inventory:

| Recipe | Result |
|---|---|
| 3 Wood Planks | Wooden Pickaxe |
| 3 Stone + 2 Sticks | Stone Pickaxe |
| 3 Iron + 2 Sticks | Iron Pickaxe |
| Dragon Scale + Iron Pickaxe | Dragon Pickaxe (does fire damage) |
| Dragon Heart + 4 Gold + Star Map Fragment | Star Compass |
| Void Core + Star Compass | Multiverse Beacon (end-game item) |
| Sand x4 | Glass x2 |
| Wood x1 | Wood Plank x4 |
| Wood Plank x4 | Chest |
| Coal + Stick | Torch x4 |

---

## 6. Visual & Audio Design

### 6.1 Visual Style
- **Low-poly / voxel hybrid** — blocks are cubic but creatures are low-poly smooth meshes
- **Color palette** — vivid, saturated colors. Each biome has a distinct palette
- **Lighting** — Dynamic sun that orbits each planet. Night brings darkness and stars
- **Particle effects** — Digging particles, fire sparks, splash water, snow, launch trail
- **Planet glow** — Distant planets have a soft atmospheric glow shader
- **Space** — Deep black with procedural star field, nebula color wash in the background
- **Weather** — Rain in Grasslands/Forest, sandstorms in Desert, blizzards in Tundra

### 6.2 Camera
- **Default:** First-person
- **Optional:** Third-person (toggle with V key) — shows player character behind
- **Planet launch:** Cinematic — pulls back to show the player arcing through space in third-person, then snaps back to first-person on landing

### 6.3 Audio Design
- **Ambient tracks** per biome — gentle wind in Grasslands, eerie echoes in Caves, crackling fire in Volcanic
- **Dynamic music** — calm exploration music swells to combat music when hostile creatures are nearby
- **Boss music** — unique dramatic theme for each boss encounter
- **Sound effects** — block dig/place, footsteps (vary by surface), creature sounds, launch whoosh, impact landing
- **Space transit** — muffled silence with a distant whooshing roar and heartbeat

---

## 7. Progression & Goals

vertexWorld is a sandbox — there is no forced progression. However, a loose narrative thread guides ambitious players:

### Narrative Arc
1. **Awaken** — Player spawns on a starter world with a single chest containing a basic pickaxe and a crumpled note reading: *"They are coming. Find the Dragon Hearts before the Void does."*
2. **Explore** — Find and kill Dragons across multiple planets, collecting Dragon Hearts
3. **Craft** — Combine a Dragon Heart with gold and a Star Map Fragment (found in ruins) to create the **Star Compass**, which reveals the location of the Dark Planet
4. **Confront** — Travel to the Dark Planet and defeat the Dark Sovereign
5. **Transcend** — The Multiverse Beacon, once crafted, creates a permanent glowing pillar on any planet the player places it on — a marker visible from space, showing other players where they've been

### Collectibles
- **Lore Tablets** — Found in ruins, each tells part of the story of a previous civilization that was destroyed by the Void
- **Ancient Coins** — Dropped by Skeleton Warriors. Purely collectible — no use, but tracked on a counter
- **Star Map Fragments** — 3 needed per Star Compass. Found in treasure chests
- **Planet Seeds** — Each planet has a unique seed string. Players can share seeds to revisit the same world

---

## 8. Technical Architecture

```
vertexWorld/
├── src/
│   ├── main.js                    # Entry — init engine, world, player, game loop
│   ├── engine/
│   │   ├── renderer.js            # Three.js WebGL renderer, scene, lighting
│   │   ├── camera.js              # FPS + cinematic camera modes
│   │   ├── inputHandler.js        # Keyboard/mouse, space charge mechanic
│   │   └── physics.js             # Spherical gravity, AABB collision
│   ├── world/
│   │   ├── planet.js              # Spherical planet mesh + block data
│   │   ├── planetManager.js       # Multi-planet system, sky planets, transit
│   │   ├── chunkManager.js        # Surface chunk load/unload around player
│   │   ├── terrain/
│   │   │   ├── generator.js       # 3D simplex noise → spherical terrain
│   │   │   └── biomes.js          # Biome rules, spawn tables
│   │   └── blocks/
│   │       ├── blockRegistry.js   # Block definitions (id, texture, hardness)
│   │       └── blockTypes.js      # Block ID constants
│   ├── creatures/
│   │   ├── creature.js            # Base FSM AI class
│   │   ├── sheep.js
│   │   ├── deer.js
│   │   ├── bunny.js
│   │   ├── wolf.js
│   │   ├── crocodile.js
│   │   ├── eagle.js
│   │   ├── caveTroll.js
│   │   ├── scorpion.js
│   │   ├── dragon.js              # Boss — flying, fire breath, phases
│   │   ├── voidWraith.js          # Space transit boss
│   │   └── darkSovereign.js       # Final boss
│   ├── player/
│   │   ├── player.js              # Health, stamina, position, state
│   │   ├── inventory.js           # Item slots, crafting grid
│   │   ├── pickaxe.js             # Tool/weapon hit detection
│   │   └── planetLaunch.js        # Planet targeting + launch trajectory
│   └── ui/
│       ├── hud.js                 # Hearts, stamina bar, hotbar
│       ├── crosshair.js           # Default + planet targeting reticle
│       ├── inventoryUI.js         # Inventory + crafting grid overlay
│       ├── planetTargetUI.js      # Planet aim ring + charge bar
│       ├── lorebook.js            # Lore tablet reading overlay
│       └── deathScreen.js         # Death + respawn UI
├── assets/
│   ├── textures/blocks/           # grass.png, stone.png, sand.png …
│   ├── textures/creatures/        # Per-creature texture atlases
│   ├── textures/ui/               # HUD elements, icons
│   ├── sounds/ambient/            # Biome ambient loops
│   ├── sounds/music/              # Exploration + combat + boss tracks
│   ├── sounds/sfx/                # Block, creature, player sound effects
│   └── fonts/                     # UI fonts
├── public/
│   └── index.html
├── tests/
│   ├── world/chunk.test.js
│   ├── world/generator.test.js
│   ├── creatures/creature.test.js
│   └── player/player.test.js
├── package.json
├── vite.config.js
├── .gitignore
└── README.md
```

---

## 9. Future Ideas & Stretch Goals

- **Multiplayer** — Multiple players on the same planet seed via WebSocket server. See other players' beacons in the sky.
- **Day/Night Cycle** — Sun orbits each planet on a 20-minute real-time cycle. More hostile creatures spawn at night.
- **Seasons** — Biome appearance changes over longer time cycles
- **Underground Civilizations** — Deep underground, procedurally generated ancient cities with puzzles and traps
- **Taming Creatures** — Feed a wolf meat 3 times to tame it as a companion that follows and fights for you
- **Boat Building** — Craft a boat to sail oceans and discover island chains
- **Portal Blocks** — Alternative to planet launch — build a portal frame and light it to create a permanent gateway between two worlds
- **Weather Events** — Rare meteor showers that crash-land meteor ore blocks on the surface
- **Player Notes** — Leave written signs on any world for future visits
- **Screenshot Mode** — Hide UI, free camera, filters — for capturing beautiful vistas
- **Procedural Dungeons** — Underground multi-level dungeons with rooms, traps, mob spawners, and a mini-boss at the bottom
- **Seasons System** — Trees lose leaves in autumn, snow covers Grasslands in winter
- **Village NPCs** — Friendly traders in ruins that will barter items for Ancient Coins
- **Fishing** — Craft a fishing rod, cast into water, minigame to reel in fish or treasure

---

## 10. Open Questions / Design Decisions

- [ ] Should the planet launch be instant-travel or show a full traversal animation through space?
- [ ] Should health regenerate passively or require eating food?
- [ ] Should crafting be grid-based (Minecraft style) or recipe-book (Terraria style)?
- [ ] Should the player keep inventory on death or drop it?
- [ ] Should there be a day/night cycle from day one or added in a later version?
- [ ] What is the maximum number of planets loaded in memory at once?
- [ ] Should planets persist between sessions (saved to localStorage/server) or regenerate from seed?

---

*This document is a living spec. Update it as design decisions are made.*
