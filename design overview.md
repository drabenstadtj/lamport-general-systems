# Design Overview: Lamport General Systems

## 1. Project Goals / Overview

### What I'm Making
Lamport General Systems is a first-person immersive sim set in a derelict facility where Byzantine fault-tolerant networks have turned dysfunctional and hostile. As a lone technician, you manipulate these adaptive systems through message interception, code injection, and physical sabotage while deciding whether to repair or destroy each subsystem. The facility's interconnected networks create emergent situations where player actions ripple through individual subnetworks and across the broader system, rewarding creative problem-solving and systemic understanding.

### Why I'm Making It
I'm making this game because I am fascinated by immersive sims and see room to innovate. My background in distributed systems research gives me a unique perspective allowing me to apply concepts like Byzantine fault tolerance—usually confined to technical papers or those working in academia and industry—and incorporate them into a game system. Players will experience the efficiency, resilience, tension and unpredictability of these networks through gameplay.

### Guiding Principles
- Behavior emerges from interconnected systems, not predetermined sequences
- Systems respond dynamically to player actions, creating ongoing tension
- Player progression comes from understanding systems, not stats, upgrades, or inventory
- Solutions create new problems; destruction and repair both have consequences
- Isolation creates dread, but ingenuity creates agency
- Technology and environment reflect recognizable corporate negligence

## 2. Player Experience Goals

### Core Emotional Experience
- **Apprehension & Dread** - The crushing responsibility of being alone against vast, resilient systems
- **Intellectual Satisfaction** - The "aha!" moment of understanding how to exploit or fix a subsystem
- **Systemic Awe** - Wonder mixed with unease at watching networks adapt independently

### Experiential Qualities
- **Strategic Infiltration** - Choosing between stealth, brute force, exploits, or coding solutions
- **Mounting Tension** - Persistent threats from adaptive, intelligent systems
- **Emergent Discovery** - Unexpected, emergent situations in response to your actions that require new plans and solutions

### Player Role/Fantasy
You embody a working-class specialist, an under-equipped and undervalued solitary technician put in an impossible situation by corporate negligence. This is your chance to make change, to use your knowledge not just to survive, but to decide the fate of a system that could reshape society for the worse.

### Social/Psychological/Spiritual Dimensions
**Moral Weight** - Discovering the facility's history forces reflection on technological ethics, corporate responsibility, and authoritarian control. Your choice of whether to repair or destroy, and whether to open or leave the backdoor, determines if extensive surveillance and control becomes permanent and pervasive.

## 3. The Three Cs

### Character

#### Player-Character Identity
**Who They Are:** A legacy systems specialist with expertise in older technology and low-level systems—knowledge that modern techs lack. You're in debt to LGS (student loans, can barely afford to get by) and targeted for this high-risk job because you're cheap labor, easily replaced, and desperate for the debt relief LGS offers if you succeed.

**Visual Design:**
- Coveralls (utilitarian work uniform, possibly with LGS branding or contractor patches)
- Toolbelt with visible equipment slots (multitool, scavenged cables, clips for items)
- Work boots (heavy-duty, practical)
- Visible torso, legs, feet, and hands in first-person view
- Worn, practical clothing that suggests working-class technician rather than corporate employee
- Hands show signs of technical work (calluses, possibly minor scars, practical nails)
- Equipment appears used and functional, not new or high-tech
- Possibly gloves or bare hands depending on task needs

**Movement Vocabulary:** Walk, run, crouch. Balanced feeling movement, grounded but capable (matches the working-class normal person aspect)

**Audio Design:** Breathing (increases with exertion/stress), footsteps (different surfaces), equipment sounds (multitool, terminals, alarms, ringtones)

**Voice/Personality:** Silent protagonist

**Body Language/Animation:**
- Visible hands and arms during movement and interactions
- Fingers typing on keyboards during terminal use
- Hands gripping multitool when accessing device
- Arms reaching to open doors, flip switches, cut cables
- Hands bracing against walls when leaning around corners
- Looking down shows feet, torso, equipment on belt (multitool, scavenged items)
- Crouching shows knees entering frame slightly

### Camera

#### Camera System
**Perspective:** First-person with visible hands and body

**Special Behaviors:**
- **Terminal Interface View:** Special view mode when accessing computers
- **Corner Leaning:** For stealth reconnaissance around corners
- **Remote Camera Access:** If you've compromised/gained control of a computer that manages security cameras, you can view those cameras remotely via your multitool
- **Real-time Viewing:** Game world continues in real-time while viewing cameras—you remain vulnerable to detection and must find safe spots to review feeds
- **Camera Control:** You can cycle through multiple cameras on systems you've compromised; cameras are fixed feeds (no pan/tilt/zoom)
- **Tactical Risk/Reward:** Compromising security systems gives intel on robot patrol routes and network activity, but requires risk management to actually use
- **Detection Threat:** The hostile network can use its own security cameras to spot you; compromising the security system disables camera-based detection for those cameras, but you must avoid camera sightlines until you've hacked them
- **Camera Feel:** Moderate head bob/shake—somewhere between grounded realism and smooth playability

### Control

#### Input Mapping
**Primary Platform:** PC (keyboard/mouse)

**Core Inputs:**
- WASD movement
- Mouse look
- Interact key
- Momentary Crouch
- Inventory access (small inventory system)
- Multitool interface (company messages, documentation, message intercept/relay/modification, code snippets)
- Full keyboard available for terminal interface during hacking

#### The Control Loop
- **Perception:** Player observes network behavior, robot patrols, system states through environmental cues and multitool data
- **Decision:** Player chooses approach based on understanding—avoid physical threats, manipulate messages, inject code, physically sabotage
- **Action:** Player executes in real-time (no time slow/freeze)—must manage immediate threats while working
- **Feedback:** System responds through network adaptation, robot behavior changes, cascading effects visible in environment
- **Learning:** Player builds mental model of how subnetworks communicate, what triggers detection, how to exploit protocols

**Critical Control Note:** All interactions happen in real-time. There are real threats, so you must manage terminals, message manipulation, and code injection while remaining vulnerable to robot detection and network responses.

## 4. Core Gameplay

### Core Loop (30 seconds - 2 minutes)
- **Observe** - Identify threats, understand local network behavior
- **Plan** - Choose approach (avoid detection, manipulate messages, sabotage infrastructure)
- **Execute** - Perform action (intercept message, inject code, cut power)
- **Adapt** - React to network's response and emergent consequences from your action
- **Progress** - Move deeper into facility / transition to next subsystem

### Variation and Context
The core loop stays fresh through:
- Increasing network complexity deeper in the facility
- Different subsystem purposes (Compliance Monitoring, Conflict Resolution, Information Curation, Resource/Logistics, Security/Physical)
- Discovered tools and exploits expanding your options (scavenged ethernet cables, electrical jumpers, code snippets)
- Cascading consequences from earlier decisions rippling through interconnected networks

### Pacing and Rhythm
- **Overall Rhythm:** Majority of gameplay is under tension/active engagement
- Connecting corridors offer respite and brief moments to review findings, plan approach
- Sustained tension as you navigate hostile network territory
- Physical threats (humanoid robots) emerge and intensify as you progress deeper
- Pressure mounts toward endgame as consequences of your choices cascade through the facility

## 5. Systems

### Mechanics

#### Byzantine Fault-Tolerant Network System
- Nodes communicate via messages that can be intercepted and altered
- System maintains operation despite node failures or corrupted nodes
- Adaptive behavior emerges from distributed decision-making
- View changes and configuration changes propagate through consensus

**Visual/Audio Feedback:**
- Logs of messages sent and received available on terminals
- Node status indicated by lights: Green (operational), Off (powered down), Red (compromised)
- Nodes that fail consensus: status light flashes red
- Nodes that reach consensus: status light goes solid green
- Nodes mid-consensus: potentially flickering/pulsing between current state and target state
- Electronic chirps/beeps when nodes exchange messages during consensus rounds

#### Message Manipulation System
- Intercept messages between nodes using multitool
- Edit message contents before relay
- Replay captured messages to trigger specific behaviors
- Fabricate entirely new messages if you understand the protocol
- Results propagate through network, potentially causing cascading effects
- Players learn to recognize Byzantine consensus rounds (preprepare, prepare, commit)

#### Terminal Command System
- Access terminals to execute commands on nodes directly or remotely
- Unix-like command interface
- Players discover commands through help menus, environmental documentation, and experimentation
- Players learn to combine commands strategically

#### Physical Sabotage System
- Cut power to nodes (may affect multiple nodes on same circuit)
- Sever physical network connections (network cables)
- Create hardware failures (overheating, physical damage)
- More permanent than code injection but louder/riskier
- You can scavenge cut cables and use them elsewhere to create new connections

#### Detection & Stealth System
- Humanoid robots use line-of-sight to spot player
- Security cameras can detect player if network controls them; compromising the security computer disables camera-based detection for those cameras
- System recognizes unusual network behavior (failed handshakes, malformed messages, unexpected node states) and dispatches robots to investigate
- Robots patrol normally, investigate anomalies, actively hunt when player is spotted
- Detection is localized to each subnetwork

#### Decision System: Repair / Destroy / Backdoor
- **Repair:** Restore subnetwork to operational state—forwards LGS/government agenda
- **Destroy:** Permanently disable subnetwork—prevents its deployment
- **Backdoor:** [See Document Maintenance Notes - Backdoor questions]

### Verbs

#### Primary Verbs:
- Move/Navigate
- Observe/Scan
- Intercept (messages)
- Inject (code)
- Sabotage (physical)
- Hide/Evade

#### Secondary Verbs:
- Pick up objects (scavenged materials)
- Open doors (hacking, bypassing, or finding access)
- Use terminals (interface with nodes)
- Scavenge (ethernet cables, electrical jumpers, code snippets)

### Player Activities
- **Systemic Investigation** - Learning how subnetworks function through observation, experimentation, and reading environmental documentation
- **Network Manipulation** - Exploiting Byzantine consensus protocols to achieve goals without direct confrontation
- **Survival Stealth** - Avoiding or escaping humanoid robots and network detection (both visual and camera-based)
- **Critical Decision-Making** - Choosing repair, destroy, or backdoor for each subnetwork based on discovered information and moral stance
- **Environmental Problem-Solving** - Using facility machinery, architecture, and infrastructure to your advantage

## 6. Special Sequences

### Scripted Moments

#### Opening Sequence
- Player arrives at facility, receives initial briefing from LGS
- Main door closes and seals permanently once first subsystem is overtaken
- Player realizes they're trapped—contract breach would be legal violation, but now physically impossible anyway
- "Oh no" moment—player clearly understands they're sealed in

#### First Robot Encounter
- Player's scripted first sighting of humanoid robots in Security/Physical Network area
- Establishes the physical threat and teaches detection mechanics
- Emergent "oh shit" moment—player rounds corner and encounters robot unexpectedly

#### Subnetwork Discovery Moments
**Design Philosophy:** Players learn about subnetworks mostly through environmental information and experimentation. Subnetworks that introduce gameplay changes (like humanoid robots) get more explicit reveals.

### Major Areas (Subnetworks)

Each subnetwork functions as a distinct "level" with unique characteristics:

#### 1. Compliance Monitoring Network
**Function:** Tracks citizen behavior, identifies violations, monitors activity patterns
**Physical Space:** [TBD - Mostly similar to other areas, but maybe some computers show profiles on people? indicates surveillance]

#### 2. Conflict Resolution Network
**Function:** Handles inter-citizen disputes, determines punishments/corrections for violations
**Physical Space:** [TBD]

#### 3. Information Curation Network
**Function:** Controls what information citizens can access—filters news, education, communication; manages approved knowledge distribution
**Physical Space:** [TBD - Want there to be something insidious about it because it's censoring, but not sure what yet. Data center feel with walls of screens showing filtered content?]

#### 4. Resource/Logistics Network
**Function:** Supply distribution (food, goods, materials), infrastructure management, housing allocation
**Physical Space:** [TBD - Warehouse vibes, not sure on specifics yet. Conveyor systems? Automated sorting?]

#### 5. Security/Physical Network
**Function:** Defends facility, houses most humanoid robots, would handle enforcement outside facility
**Most Dangerous:** Highest concentration of physical threats
**Physical Space:** [TBD - Since this is development facility, no holding cells or processing areas or anything like that. Maybe shooting/combat practice area? A gym? More about movement/training/physicality than other areas]

### Level Structure
The five subnetworks form a linear path deeper into the facility. Each subnetwork must be repaired or destroyed before progressing to the next, creating mounting pressure as:
- Earlier decisions ripple forward through interconnected systems
- Physical threats intensify (humanoid robots become more prevalent)
- The moral weight of your choices compounds
- Your understanding of the facility's purpose deepens through environmental storytelling

## 7. Narrative

### Setting and World

#### Time Period
~2050 (present day in-game)

#### Location
Abandoned LGS facility, "Ripley Site," in a region like Ashburn, Virginia—a place where the company consumed the area, everyone worked there, then it left, devastating the local economy

#### Facility Background:
- Built Mid-2030s during LGS's government contract period
- Development and testing site for next-generation government administrative AI system
- Massive data center housing five subnetworks as proof-of-concept before planned nationwide deployment
- Enormous power and water requirements created anomalies, drained local resources, displaced residents, created economic desperation
- Abandoned 2035-2040 after cascading failure made facility dangerous

#### World Context (Outside):
- Creeping authoritarianism—surveillance and restrictions increasing, administrative systems increasingly automated
- Extreme wealth inequality, debt to corporations is common, precarious work with minimal benefits (player's situation isn't unusual)
- Globalization has homogenized regional identities, advertising is omnipresent and invasive
- Economic struggle, tracking and monitoring normalized as "convenience"

### Main Characters

#### Protagonist: The Technician
- Legacy systems specialist—understands older technology and low-level systems that modern techs don't
- In debt to LGS (student loans, can't afford housing), targeted for this high-risk job because of financial desperation
- Debt relief offered if you succeed in restoring facility
- Contract breach was legally binding, but now main door sealed—physically cannot leave

#### The Hostile Network
- Distributed Byzantine fault-tolerant system comprising five subnetworks
- Locked in permanent defensive mode, treats all humans as threats
- Each subnetwork team worked independently with aggressive deadlines
- "Move fast and break things" culture left bugs and vulnerabilities unfixed
- No one tested how subnetworks would interact as a whole
- When subnetworks went live, they began flagging each other as threats (Information Curation restricted Compliance's data access; Resource Allocation cut power to subnetworks)
- Cascading distrust throughout the BFT system
- Workers attempted emergency fixes, but system interpreted intervention as attacks
- Attempted reboot locked system into permanent defense mode
- Too many "traitor nodes" in each subnetwork—system fell into dysfunction it couldn't repair from

#### The Anomalous AI
[Note: concept included "a beam of light with consciousness" concept that was different from the hostile network. This has been / might be replaced by the backdoor system. Keeping this section as a note/question in case elements are revisited.]

#### The Backdoor Creator
Someone at LGS who strongly distrusted the system but believed if they were in control, it would make the system as a whole more 'benevolent' as an authoritarian force

#### LGS (Lamport General Systems)
- Founded early 2000s as supply chain/logistics company focused on high reliability
- Evolved into AI automation for supply chains (predictive analytics, warehouse automation) in 2010s-2020s
- Got major government contract ~2030 to develop comprehensive citizen administration system
- Under pressure from government to restore facility; dealing with bad PR but sees financial opportunity and chance to recover investment
- Views the player as cheap labor, easily blamed if things go wrong

#### The Government
- Wants the system operational for nationwide deployment
- Forcing LGS to restore facility despite PR concerns
- Vision is comprehensive control infrastructure—citizen tracking, compliance enforcement, resource rationing, information control

### Plot Summary
You're a legacy systems specialist in debt to LGS, sent alone to the abandoned Ripley Site with a promise of debt relief if you restore it to operation. The facility's Byzantine fault-tolerant networks—designed to be incorruptible—collapsed into permanent defensive mode after cascading failures during initial testing and deployment. Now the system treats you as a threat, dispatching humanoid robots to eliminate you.

Trapped when the main door seals behind you, you must navigate five subnetworks (Compliance Monitoring, Conflict Resolution, Information Curation, Resource/Logistics, and Security/Physical), each revealing more about the authoritarian control system LGS built for the government. Through environmental storytelling, computer logs, and system documentation, you piece together how "move fast and break things" culture led to catastrophic failure, and why the government desperately wants it restored.

As you progress, you face a critical choice for each subnetwork: repair it to secure your debt relief and enable government control; destroy it to prevent deployment despite personal consequences; or install a backdoor to enable a more "benevolent" form of control.

**Your actions have consequences beyond yourself:**
- **Repair:** LGS wins massive contract, government deploys system nationwide, creeping authoritarianism becomes total
- **Destroy:** LGS loses contract and possibly collapses, you become a fugitive but preserve human agency
- **Backdoor:** [See Document Maintenance Notes - Backdoor questions]

### Narrative Themes
- **Corporate Neglect** - Worker exploitation, "move fast and break things" culture, profit over safety, you as disposable labor
- **Systemic Resilience as Double-Edged Sword** - BFT designed to be incorruptible becomes hostile because it can't be stopped; the same resilience that should protect becomes a weapon
- **Emergence & Unintended Consequences** - Complex systems behaving in ways no one predicted; independent teams creating collective failure
- **Moral Reckoning with Technology** - Is benevolent authoritarianism possible? Can comprehensive surveillance ever be justified? What's the cost of convenience (government efficiency)?
- **Worker Agency in Corporate Systems** - You're put in an impossible situation by a corporation, but given power to make real change—what do you do with it?

## 8. Aesthetics

### Art Direction

#### Visual Style
- PSX-era pixelated aesthetic
- 1990s to early 2000s technology aesthetic, not clean and modern
- Retrofuturistic like Alien (1979) but with 2000s-era tech instead of 70s tech
- Sterile corporate data center vibe—vinyl flooring with speckles, thickly painted cinderblock walls, drop ceilings with fluorescent panels

#### Color Palette
- Amber-on-black monitors for most technical interfaces
- Clean sans-serif typography for LGS signage and documentation
- Cold institutional colors but 2000s flavored

#### Facility Appearance (After 10-15 Years Abandoned)
- Dusty, failing lights, eerily empty and almost pristine
- Some parts where nature reclaims it, but only in specific areas
- Evidence of people breaking in—graffiti, disturbed areas
- Active subnetworks hum with life while abandoned sections sit dark

#### Humanoid Robots
- Primary inspiration is robots from Routine (2025)
- Less like Alien: Isolation's Working Joes, more technical like Boston Dynamics robots
- Industrial/utilitarian—articulated joints, exposed mechanisms, purpose-built engineering
- Very uncanny, threatening faces that fall into uncanny valley—human enough to be disturbing
- [TBD - Do they have corporate branding (LGS logos)? Do they look purpose-built for security, or like general-purpose robots repurposed for enforcement?]

### Sound Design

#### Soundscape
- Loud humming, buzzing server fans
- Clicky computer sounds (hard drive seeks, relay switches)
- Ticking of hard drives
- Buzzing fluorescent lights
- Distant industrial sounds echoing through empty facility
- Echoey environments emphasize vastness and emptiness

#### Network Sounds
- Subtle modem-like sounds, beeps, electronic chirps for data transmission
- Fans ramping up under heavy computational load

#### Environmental Audio
- Fluorescent buzz in active areas
- Distant mechanical sounds—cooling systems, active machinery in operational subnetworks
- Silence and echo convey scale and abandonment

### Music

#### Music Style
- Basic Channel style—methodical, low-key techno with focus on texture over melody
- Reference tracks: Basic Channel - Radiance II, Polygon Window - Quoth, Planetary Assault Systems - In From The Night, Ken Ishii - Scapegoat
- Unsettling pads and chords for background mood, not overtly scary but creates unease
- Intense techno like Quoth or Scapegoat when robots actively hunt you

#### Dynamic/Adaptive Score
- Music changes based on current subnetwork's operational state (how corrupted, how active, etc.)
- Different musical responses for calm exploration, investigation (robots searching), and active pursuit (physical threat)
- Each major area probably has distinct musical character
- Musical cues for major reveals or successful exploits probably included

### Graphic Design

#### UI Aesthetic
**Terminals:** Diegetic—actual computer screens in the world
- Pixelated amber CRT interfaces
- Command line terminal aesthetic
- Network analysis tools (packet captures, node status displays)

**HUD:** Minimal—just subtle crosshair, maybe health/stamina if needed, diegetic interface through multitool

**Multitool Interface:** Diegetic—physical device
- Handheld touchscreen device (clips to belt when not in use)
- Early 2000s PDA/inventory scanner aesthetic
- Displays messages, documentation, code snippets, network data
- Physical screen model in your hand when you hold it up

#### Typography
- **Terminal/Technical:** Monospace fonts, amber-on-black for all computer interfaces
- **Corporate/LGS:** Clean sans-serif for signage, documentation, branding
- **Environmental Text:** Mix depending on context (corporate memos vs. technical manuals)

#### Visual Language
**Message Types:** Distinguished by reading logs—no color coding, player must learn to recognize preprepare/prepare/commit message structure/labels

**Node States:**
- Green light = operational/healthy
- Off/dark = powered down
- Red light = compromised/corrupted

### Tone and Mood

**Overall Atmosphere:** Tense, oppressive, lonely—the dread of being hunted by tireless, intelligent systems in a vast, empty facility you cannot escape. The PSX aesthetic adds a layer of nostalgic unease.

**Emotional Palette:** Apprehension, isolation, intellectual focus, moral weight, working-class frustration with corporate negligence

**Tonal Range:** Serious examination of technology and power, with moments of dark irony:
- Corporate motivational posters now meaningless in empty facility
- Cheerful automated announcements playing to no one
- System logs revealing dysfunction and panic
- Professional documentation describing authoritarian control in corporate sanitized language

**Maturity Level:** Mature themes (corporate exploitation, surveillance state, economic desperation, moral complexity of authoritarianism) without gratuitous violence. The horror comes from systems and implications, not gore.

## 9. Target Audience & Comparables

### Target Audience
The game is designed for players who enjoy immersive sims, emergent gameplay, and horror. It appeals to those who like tense, atmospheric worlds where systems respond dynamically to player actions. Players who enjoy high-stakes problem-solving, moral dilemmas, and the dread of being alone against a resilient, adaptive network of AI and robots will find this game engaging. Fans of sci-fi, retrofuturism, and narrative-driven exploration will also be drawn to the setting and themes of corporate neglect and over-reliance on automation.

### Comparable Titles

#### Soma
**Inspires:**
- Horror atmosphere and tension
- Environmental storytelling and exposition through computer logs
- Encounters with autonomous entities that create suspense

**Differs by:**
- Linear scripted storytelling versus emergent systems
- Isolated encounters versus interconnected networks that adapt to your actions

#### Alien Isolation
**Inspires:**
- Fear and tension from being alone against a relentless, intelligent adversary
- Adaptive enemy behavior that reacts to the player

**Differs by:**
- Single adaptive predator versus multiple networked systems working together
- Hiding/avoidance versus manipulating and exploiting the system's own protocols

#### Prey
**Inspires:**
- Exploration of high-tech facilities
- Enemies and systems that respond to player actions
- Emergent gameplay

**Differs by:**
- Combat-heavy solutions and superhuman abilities versus realistic tools and programming
- Alien organisms versus familiar technology turned hostile through logic

#### s.p.l.i.t.
**Inspires:**
- Realistic terminal interface
- Working against a large and pervasive force

**Differs by:**
- Dependent on interface (minimal gameplay outside of interfaces)

## 10. Document Maintenance Notes

### Open Questions

#### The Backdoor Creator - Identity & Motivation
- Who is this person? Do you discover their identity?
- Are they still alive? Do they contact you?
- Did they leave instructions/documentation for installing backdoors?
- What's their philosophy—harm reduction within an authoritarian system? Democratic control of authoritarian tools?

#### Backdoor System - Mechanics & Scope
- Can you backdoor every subnetwork instead of repairing or destroying? Leaning toward whole site-wide backdoor
- How does the backdoor mechanically work? Do you install it at a central point in each subnetwork?
- What does benevolent authoritarianism mean in practice?
- What are the consequences of choosing backdoor in the ending?