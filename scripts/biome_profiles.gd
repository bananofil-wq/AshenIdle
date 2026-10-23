extends RefCounted
## Deterministic biome dressing rules for ten-stage journeys.
## Each profile is selected by floor; bosses occupy floors 10, 20, 30...
const THEMES = [
 {"name":"Cave Crypt","ground":Color("#514a49"),"accent":Color("#9b6b54"),"props":["stalagmite","broken_pillar","skull_pile"],"fog":Color("#342d39")},
 {"name":"Enchanted Forest","ground":Color("#465d38"),"accent":Color("#a2cc73"),"props":["oak","fern","mushroom"],"fog":Color("#536d57")},
 {"name":"Swamp of Decay","ground":Color("#414b36"),"accent":Color("#9baa50"),"props":["dead_tree","reeds","bog_pool"],"fog":Color("#576447")},
 {"name":"Frozen Cavern","ground":Color("#7b9ea9"),"accent":Color("#bceaff"),"props":["ice_spire","snow_drift","crystal"],"fog":Color("#8caec2")},
 {"name":"Infernal Wastes","ground":Color("#44352f"),"accent":Color("#ff6736"),"props":["lava_crack","basalt","ember_vent"],"fog":Color("#6b342d")},
 {"name":"Haunted Grave Kingdom","ground":Color("#47474d"),"accent":Color("#b0a4ce"),"props":["gravestone","dead_tree","crypt"],"fog":Color("#50475e")},
 {"name":"Sunscar Desert","ground":Color("#b39460"),"accent":Color("#f5ce84"),"props":["dune","ruin","cactus"],"fog":Color("#c7a16e")},
 {"name":"Storm Peaks","ground":Color("#69767a"),"accent":Color("#8dcaff"),"props":["cliff","pine","obelisk"],"fog":Color("#647a8d")},
 {"name":"Corrupted Moon Temple","ground":Color("#4a425e"),"accent":Color("#bb81ed"),"props":["moon_pillar","altar","crystal"],"fog":Color("#51446d")},
 {"name":"Celestial Rift","ground":Color("#353b62"),"accent":Color("#8fe5ff"),"props":["floating_shard","star_pillar","rift"],"fog":Color("#454c83")}
]
static func profile_for_stage(stage:int)->Dictionary:
 return THEMES[posmod(int((maxi(stage,1)-1)/10),THEMES.size())]
static func is_boss(stage:int)->bool:
 return stage>0 and stage%10==0
static func prop_for(stage:int, index:int)->String:
 var props:Array=profile_for_stage(stage)["props"]
 return props[posmod(index*7+stage*3,props.size())]
static func seed_for(stage:int, room:int)->int:
 return (stage*73856093) ^ (room*19349663)
