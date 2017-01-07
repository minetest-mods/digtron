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

Detailed module guide
=====================

Control Module
--------------

Right-click on this module to make the digging machine go one step. The digging machine will go in the direction that the control module is oriented.

A control module can only trigger once per second. Gives you time to enjoy the scenery and smell the flowers (or their mulched remains, at any rate).

If you're standing within the digging machine's volume, or in a node adjacent to it, you will be pulled along with the machine when it moves.

Automatic Control Module
--------------

An Auto-control module can be set to run for an arbitrary number of cycles. Once it's running, right-click on it again to interrupt its rampage. If anything interrupts it - the player's click, an undiggable obstruction, running out of fuel - it will remember the number of remaining cycles so that you can fix the problem and set it running again to complete the original plan.

The digging machine will go in the direction that the control module is oriented.

Pusher Module
-------------

Aka the "can you rebuild it six inches to the left" module. This is a much simplified control module that does not trigger the digger or builder heads when right-clicked, it only moves the digging machine. It's up to you to ensure there's space for it to move into.

Since movement alone does not require fuel, a pusher module has no internal furnace.

Digger Head
-----------

Facing of a digger head is significant; it will excavate material from the node on the spinning grinder wheel face of the digger head. Generally speaking, you'll want these to face forward - though having them aimed to the sides can also be useful.

Digger heads come in both regular and "intermittent" versions, each of which is craftable from the other. The intermittent version can have a period and offset defined if you want them to punch regularly-spaced holes. Note that diggers aimed forward should generally always be the regular kind (or have a period of 1), otherwise the digging machine may be unable to move.

Soft Material Digger Head
----------------

This specialized digger head is designed to excavate only softer material such as sand or gravel. It has no period/offset settings; it will always attempt to dig sand when it's present in its target node. It leaves all other types of nodes alone. In technical terms, this digger digs nodes belonging to the "crumbly", "choppy", "snappy", "oddly_diggable_by_hand" and "fleshy" groups. It also comes in regular and "intermittent" versions.

The intended purpose of this digger is to be aimed at the ceiling or walls of a tunnel being dug, making spaces to allow shoring nodes to be inserted into unstable roofs but leaving the wall alone if it's composed of a more stable material.

It can also serve as part of a lawnmower or tree-harvester.

Builder Head
------------

A builder head is the most complex component of this system. It has period and offset properties, and also an inventory slot where you "program" it by placing an example of the node type that you want it to build. The builder doesn't keep a real copy of the item, it just reads what you drop in here.

When the "Save & Show" button is clicked the properties for period and offset will be saved, and markers will briefly be shown to indicate where the nearest spots corresponding to those values are. The builder will build its output at those locations provided it is moving along the matching axis.

The "output" side of a builder is the side with a black crosshair on it.

Builders also have a "facing" setting. If you haven't memorized the meaning of the 24 facing values yet, builder heads have a helpful "Read & Save" button to fill this value in for you. Simply build a temporary instance of the node in the output location in front of the builder, adjust it to the orientation you want using the screwdriver tool, and then when you click the "Read & Save" button the node's facing will be read and saved.

Inventory Module
----------------

Inventory modules have the same capacity as a chest. They're used both for storing the products of the digger heads and as the source of materials used by the builder heads. A digging machine whose builder heads are laying down cobble can automatically self-replenish in this way, but note that an inventory module is still required as buffer space even if the digger heads produced everything needed by the builder heads in a given cycle.

Inventory modules are not required for a digging-only machine. If there's not enough storage space to hold the materials produced by the digging heads the excess material will be ejected out the back of the control node. They're handy for accumulating ores and other building materials, though.

Digging machines can have multiple inventory modules added to expand their capacity.

Fuel Hopper Module
------------------

Digtrons have an appetite. Build operations and dig operations require a certain amount of fuel, and that fuel comes from fuel hopper modules. Note that movement does not require fuel, only digging and building.

When a control unit is triggered, it will tally up how much fuel is required for the next cycle and then burn items from the fuel hopper until a sufficient amount of heat has been generated to power the operation. Any leftover heat will be retained by the control unit for use in the next cycle; this is the "heat remaining in controller furnace". This means you don't have to worry too much about what kinds of fuel you put in the hopper, none will be wasted (unless you dig away a control unit with some heat remaining in it, that heat does get wasted).

The fuel costs for digging and building can be configured in the init.lua file. By default using one lump of coal as fuel a digtron can:

* Build 40 nodes
* Dig 40 stone nodes
* Dig 60 wood nodes
* Dig 80 dirt or sand nodes

Combined Storage Module
-----------------------

For smaller jobs the two dedicated modules may simply be too much of a good thing, wasting precious Digtron space to give unneeded capacity. The combined storage module is the best of both worlds, splitting its internal space between building material inventory and fuel storage. It has 3/4 building material capacity and 1/4 fuel storage capacity.

Structural Module
-----------------

These nodes allow otherwise-disconnected sections of digtron nodes to be linked together. They are not usually necessary for simple diggers but more elaborate builder arrays might have builder nodes that can't be placed directly adjacent to other digtron nodes and these nodes can serve to keep them connected to the controller.

They may also be used for providing additional traction if your digtron array is very tall compared to the terrain surface that it's touching.

You can also use them decoratively, or to build a platform to stand on as you ride your mighty mechanical leviathan through the landscape.

Digtron Lamp
------------

A light source that moves along with the digging machine. Convenient if you're digging a tunnel that you don't intend to outfit with torches or other permanent light fixtures. Not quite as bright as a torch since the protective lens tends to get grimy while burrowing through the earth.

Digtron core
------------

The only non-node item in this mod is the Digtron core, a crafting item used to manufacture the various Digtron components. Each component recipe has a Digtron core in it.  Some of the cheaper parts of a Digtron can be recycled to get the valuable core back out for use in other Digtron parts.

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