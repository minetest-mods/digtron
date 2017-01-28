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

Note for modders: if you wish to make a node impenetrable to Digtron's digging, add it to the "digtron_protected" group.

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

