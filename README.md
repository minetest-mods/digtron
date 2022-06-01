# Modular Tunnel Boring Machine
## aka The Almighty Digtron


This mod contains a set of blocks that can be used to construct highly customizable and modular tunnel-boring machines, bridge-builders, road-pavers, wall-o-matics, and other such construction/destruction contraptions.

A digging machine's components must be connected to the control block via a path leading through the faces of the blocks - diagonal connections across edges and corners don't count. 

The basic block types that can be assembled into a functioning digging machine are:

* Digger heads, which excavate material in front of them when the machine is triggered
* Builder heads, which build a user-configured node in the direction they're facing
* Inventory modules, which hold material produced by the digger and provide material to the builders
* Fuel modules, which holds flammable materials to feed the beast
* Control block, used to trigger the machine and move it in a particular direction.

Diggers mine out blocks and shunt them into the Digtron's inventory, or drop them on the ground if there isn't room in the inventory to store them.

Builder heads can be used to lay down a solid surface as the Digtron moves, useful for situations where a tunnel-borer intersects a cavern. Builder heads can be set to construct their target block "intermittently", allowing for regularly-spaced structures to be constructed. Common uses include building support arches at regular intervals in a tunnel, adding a torch on the wall at regular intervals, laying rails with regularly-spaced powered rails interspersed, and adding stairs to vertical shafts.

The auto-controller block is able to trigger automatically for a user-selected number of cycles. A player can ride their Digtron as it goes.

Other specialized Digtron blocks include:

* An "axle" block that allows an assembled Digtron to be rotated into new orientations without needing to be rebuilt block-by-block
* A crate that can store an assembled Digtron and allow the player to transport it to a new location
* A duplicator that can create a copy of an existing Digtron (if provided with enough spare parts)
* An item ejector to clear Digtron's inventory of excavated materials and inject it into pipeworks tubes if that mod is installed.
* A light that can be mounted on a Digtron to illuminate the workspace as it moves
* Structural components to make it look cool

The Digtron mod only depends on the default mod, but includes optional support for several other mods:

* [doc](https://forum.minetest.net/viewtopic.php?t=15912), an in-game documentation mod. Detailed documentation for all of the Digtron's individual blocks are included as well as pages of general concepts and design tips.
* [pipeworks](https://forum.minetest.net/viewtopic.php?id=2155), a set of pneumatic tubes that allows inventory items to be extracted from or inserted into Digtron inventories.
* [hopper](https://forum.minetest.net/viewtopic.php?&t=12379), a different mod for inserting into and extracting from Digtron inventories. Note that only [the most recent version of hopper is Digtron-capable,](https://github.com/minetest-mods/hopper) earlier versions lack a suitable API.
* [awards](https://forum.minetest.net/viewtopic.php?&t=4870), a mod that adds achievements to the game. Over thirty Digtron-specific achievements are included.
* [technic](https://forum.minetest.net/viewtopic.php?f=11&t=2538), which adds rechargeable batteries and power cables to the game that Digtron can use instead of fuel.
