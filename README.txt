			Modular Tunnel Boring Machine, aka
				  The Almighty Digtron
				  ====================

This mod contains a set of nodes that can be used to construct highly customizable and modular tunnel-boring machines, bridge-builders, road-pavers, wall-o-matics, and other such construction/destruction contraptions.

The basic nodes that can be assembled into a functioning digging machine are:

* Digger heads, which excavate material in front of them when the machine is triggered
* Builder heads, which build a user-configured node in front of them
* Inventory modules, which hold material produced by the digger and provide material to the builders
* Control node, used to trigger the machine and move it in a particular direction.

A digging machine's components must be connected to the control node via a path leading through the faces of the nodes - diagonal connections across edges and corners don't count.

Important general concepts
--------------------------

Several general concepts are important when building more sophisticated diggers.

* Facing - a number between 0-23 that determines which direction a node is facing and what orientation it has. Not all nodes make use of facing (basic blocks such as cobble or sand have no facing, for example) so it's not always necessary to set this when configuring a builder head. The facing of already-placed nodes can be altered through the use of the screwdriver tool.

* Period - Builder and digger heads can be made periodic by changing the period value to something other than 1. This determines how frequently they trigger. A period of 1 triggers on every node, a period of 2 triggers once every second node, a period of 3 triggers once every third node, etc. These are useful when setting up a machine to place regularly-spaced features as it goes. For example, you could have a builder head that places a torch every 8 steps, or a digger node that punches a landing in the side of a vertical stairwell at every level.

* Offset - The location at which a periodic module triggers is globally uniform. This is handy if you want to line up the nodes you're building (for example, placing pillars and a crosspiece every 4 nodes in a tunnel, or punching alcoves in a wall to place glass windows). If you wish to change how the pattern lines up, modify the "offset" setting.

* Shift-right-clicking - since most of the nodes of the digging machine have control screens associated with right-clicking, building additional nodes on top of them or rotating them with the screwdriver requires the shift key to be held down when right-clicking on them.

What Do These Noises Mean?
==========================

When a digging machine is unable to complete a cycle it will make one of several noises to indicate what the problem is. It will also set its mouseover text to explain what went wrong.

Squealing traction wheels indicates a mobility problem. If the squealing is accompanied by a buzzer, the digging machine has encountered an obstruction it can't dig through. This could be a protected region (the digging machine has only the priviledges of the player triggering it), a chest containing items, or perhaps the digger was incorrectly designed and can't dig the correctly sized and shaped cavity for it to move forward into. There are many possibilities.

Squealing traction wheels with no accompanying buzzer indicates that the digging machine doesn't have enough solid adjacent nodes to push off of. Tunnel boring machines cannot fly or swim, not even through lava, and they don't dig fast enough to "catch sick air" when they emerge from a cliffside. If you wish to cross a chasm you'll need to ensure that there are builder heads placing a solid surface as you go. If you've built a very tall digtron with a small surface footprint you may need to improve its traction by adding structural modules that touch the ground.

A buzzer by itself indicates that the Digtron has run out of fuel. There may be traces remaining in the hopper, but they're not enough to execute the next dig/build cycle.

A ringing bell indicates that there are insufficient materials in inventory to supply all the builder heads for this cycle.

A short high-pitched honk means that one or more of the builder heads don't have an item set. A common oversight, especially with large and elaborate digging machines, that might be hard to notice and annoying to fix if not noticed right away.

Splooshing water sounds means your Digtron is digging adjacent to (or through) water-containing nodes. Digtrons are waterproof, but this might be a useful indication that you should take care when installing doors in the tunnel walls you've placed here.

A triple "voop voop voop!" alarm indicates that there is lava adjacent to your Digtron. Digtrons can't penetrate lava by default, and this alarm indicates that a non-lava-proof Digtron operator may wish to exercise caution when opening the door to clear the obstruction.

Pipeworks Compatible
====================

If you happen to have the Pipeworks mod installed (https://github.com/minetest-mods/pipeworks), the three inventory modules are Pipeworks-compatible. When a Digtron moves one of the inventory modules adjacent to a pipe it will automatically hook up to it, and disconnect again when it moves on.

Inventory modules act like chests.

Fuel modules act like chests, but will reject any non-fuel items that try to enter them.

Combination modules act like furnances. For the most part, that means they act like chests - items are extracted from the "main" inventory, and items coming into the combination module are inserted into "main". However, a pipe entering the combination module from the underside will attempt to insert items into the "fuel" inventory.

Note that Pipeworks is entirely optional, you don't need to install it.

Crafting recipes
================

All machine nodes are constructed from a "Digtron Core" craft item and other materials.

Digtron cores are made with the following recipe:

[     ,     steel    ,      ]
[steel, mese fragment, steel]
[     ,     steel    ,      ]
			
Digger heads:

[       , diamond ,        ]
[diamond,  core   , diamond]
[       , diamond ,        ]

Sand/gravel digger heads:

[     , steel ,      ]
[steel, core  , steel]
[     , steel ,      ]

Builder heads:

[             , mese fragment,              ]
[mese fragment,     core     , mese fragment]
[             , mese fragment,              ]

Controller:
		
[            , mese crystal,             ]
[mese crystal,     core    , mese crystal]
[            , mese crystal,             ]

Automatic Controller:
		
[mese crystal, mese crystal, mese crystal]
[mese crystal,     core    , mese crystal]
[mese crystal, mese crystal, mese crystal]

Inventory modules:

[chest,]
[core,]

Fuel storage modules:

[furnace,]
[core,]

Combined storage:

[furnace,]
[core,]
[chest,]

Structural modules:

[stick,      , stick]
[     , core ,      ]
[stick,      , stick]

Panel:

[     ,      ,      ]
[     , core ,      ]
[     , steel,      ]

Edge panel:

[     ,      ,      ]
[     , core , steel]
[     , steel,      ]

Corner panel:

[     ,      ,      ]
[     , core , steel]
[     , steel, steel]


Lantern module:

[torch,]
[core,]
	
Pusher controller:

[    , coal ,     ]
[coal, core , coal]
[    , coal ,     ]


Tips and tricks
===============

To more easily visualize the operation of a Digtron, imagine that its cycle of operation follows these steps in order:

* Dig
* Move
* Build
* Allow dust to settle (ie, sand and gravel fall)

If you're building a repeating pattern of nodes, your periodicity should be one larger than your largest offset. For example, if you've laid out builders to create a set of spiral stairs and the offsets are from 0 to 11, you'll want to use periodicity 12.

A good way to program a set of builders is to build a complete example of the structure you want them to create, then place builders against the structure and have them "read" all of its facings. This also lets you more easily visualize the tricks that might be needed to allow the digtron to pass through the structure as it's being built.