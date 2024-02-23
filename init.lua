local abs, sqrt, min, max, random, floor, ceil, log, exp, atan2 = math.abs, math.sqrt, math.min, math.max, math.random, math.floor, math.ceil, math.log, math.exp, math.atan2
local nodes, id, name = minetest.registered_nodes, minetest.get_content_id, minetest.get_name_from_content_id

local id, name = minetest.get_content_id, minetest.get_name_from_content_id
local posString = minetest.pos_to_string

local baseHeightDef = {
    offset = 0,
    scale = 6,
    spread = {x = 500, y = 500, z = 500},
    octaves = 8,
    persistence = 0.5,
    lacunarity = 2,
    seed = 24249249
}
local lowNoiseDef = {
    offset = 0,
    scale = 64,
    spread = {x = 250, y = 400, z = 250},
    octaves = 7,
    persistence = 0.5,
    lacunarity = 2,
    seed = 135531
}
local highNoiseDef = {
    offset = 0,
    scale = 64,
    spread = {x = 250, y = 400, z = 250},
    octaves = 7,
    persistence = 0.5,
    lacunarity = 2,
    seed = 225252
}
local selectorDef = {
    offset = 0.5,
    scale = 12,
    spread = {x = 60, y = 120, z = 60},
    octaves = 5,
    persistence = 0.5,
    lacunarity = 2,
    seed = 767567
}
local eroderDef = {
    offset = 1,
    scale = 5,
    spread = {x = 120, y = 180, z = 120},
    octaves = 6,
    persistence = 0.5,
    lacunarity = 2,
    seed = 229194
}
local cavesADef = {
    offset = 0,
    scale = 1,
    spread = {x = 25, y = 15, z = 25},
    octaves = 1,
    persistence = 0.5,
    lacunarity = 2,
    seed = 484382
}
local cavesBDef = {
    offset = 0,
    scale = 1,
    spread = {x = 25, y = 15, z = 25},
    octaves = 1,
    persistence = 0.5,
    lacunarity = 2,
    seed = 2218418
}
local caveEntrancesDef = {
    offset = 0,
    scale = 1,
    spread = {x = 100, y = 100, z = 100},
    octaves = 1,
    persistence = 0.5,
    lacunarity = 2,
    seed = 9918281
}
local caveDeadendsDef = {
    offset = 0,
    scale = 1,
    spread = {x = 200, y = 100, z = 200},
    octaves = 1,
    persistence = 0.5,
    lacunarity = 2,
    seed = 9918281
}

local function smootherstep(x)
    return x * x * x * (x * (x * 6 - 15) + 10)
end
local function clamp(x, a, b)
    return min(max(x, a), b)
end
local function lerp(x, y, t)
    return x + (y - x) * t
end
local function sigmoid(x)
    return x / sqrt(1 + x^2)
end

minetest.register_on_generated(function (minp, maxp, seed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local heatMap, humidityMap = minetest.get_mapgen_object("heatmap"), minetest.get_mapgen_object("humiditymap")
    local emin2d = {x = emin.x, y = emin.z, z = 0}
    
    local esize = vector.add(vector.subtract(emax, emin), 1)
    local esize2d = {x = esize.x, y = esize.z}
    
    local area = VoxelArea:new {MinEdge = emin, MaxEdge = emax}
    local data = vm:get_data()
    
    local baseHeightMap = minetest.get_perlin_map(baseHeightDef, esize2d):get_2d_map(emin2d)
    local lowNoiseMap = minetest.get_perlin_map(lowNoiseDef, esize):get_3d_map_flat(emin)
    local highNoiseMap = minetest.get_perlin_map(highNoiseDef, esize):get_3d_map_flat(emin)
    local selectorMap = minetest.get_perlin_map(selectorDef, esize):get_3d_map_flat(emin)
    local eroderMap = minetest.get_perlin_map(eroderDef, esize):get_3d_map_flat(emin)
    local cavesAMap = minetest.get_perlin_map(cavesADef, esize):get_3d_map_flat(emin)
    local cavesBMap = minetest.get_perlin_map(cavesBDef, esize):get_3d_map_flat(emin)
    local caveDeadendsMap = minetest.get_perlin_map(caveDeadendsDef, esize):get_3d_map_flat(emin)
    local caveEntrancesMap = minetest.get_perlin_map(caveEntrancesDef, esize):get_3d_map_flat(emin)
    
    for x = minp.x, maxp.x do
        for z = minp.z, maxp.z do
            for y = minp.y, maxp.y do
                local index = area:index(x, y, z)
                local density = lerp(lowNoiseMap[index], highNoiseMap[index], clamp(selectorMap[index], 0, 1)) - (y * (y < 0 and 4 or 1) - baseHeightMap[z - minp.z + 1][x - minp.x + 1]) * max(eroderMap[index], 1)
                
                local node
                if density >= 0 then
                    node = id("mapgen_stone")
                elseif y <= 1 then
                    node = id("mapgen_water_source")
                else
                    node = id("air")
                end
                
                local oldNode = data[index]
                if node ~= id("air") and node ~= id("mapgen_water_source") or oldNode == id("air") or oldNode == id("mapgen_water_source") then
                    data[index] = node
                end
            end
        end
    end
    
    biomegen.generate_biomes(data, area, minp, maxp)
    vm:set_data(data)
    minetest.generate_ores(vm, minp, maxp)
    
    vm:get_data(data)
    for x = minp.x, maxp.x do
        for z = minp.z, maxp.z do
            for y = minp.y, maxp.y do
                local index = area:index(x, y, z)
                
                if ((1 - abs(cavesAMap[index])) * (1 - abs(cavesBMap[index]))) - clamp(1 - abs(caveDeadendsMap[index]), 0, 1) ^ 10 - clamp(min(y, 0) / 64 - caveEntrancesMap[index], 0, 1) > 0.85 then
                    data[index] = id("air")
                end
            end
        end
    end
    vm:set_data(data)
    
    biomegen.place_all_decos(data, area, vm, minp, maxp, seed)
    vm:get_data(data)
    biomegen.dust_top_nodes(data, area, vm, minp, maxp)
    
    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map()
    vm:update_liquids()
end)