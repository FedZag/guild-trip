-- ONE: observe only the character's actual taxi map; do not guess discovery
-- from C_TaxiMap.GetTaxiNodesForMap (known to be inaccurate on Forever).
local _, guild = ...
local ONE = _G.ProjectONE
local Flights = {current=nil, captured=0}
guild.FlightPoints = Flights

local function CharacterKey()
    if type(UnitFullName)=='function' then
        local a,b=UnitFullName('player')
        if a and a~='' then return a..'-'..(b or '') end
    end
    if type(UnitName)=='function' then return UnitName('player') end
end
local function NodeKey(node, index)
    if node and type(node.nodeID)=='number' and node.nodeID>0 then
        return 'id:'..node.nodeID
    end
    local name=node and node.name
    if not name and type(TaxiNodeName)=='function' then
        local ok,result=pcall(TaxiNodeName,index)
        if ok then name=result end
    end
    if type(name)=='string' and name~='' and name~='INVALID' then
        return 'name:'..name:lower()
    end
end
local function State(node,index)
    if node and type(node.state)=='number' then
        if node.state==0 then return 'CURRENT' end
        if node.state==1 then return 'REACHABLE' end
        return 'DISTANT'
    end
    if type(TaxiNodeGetType)=='function' then
        local ok,state=pcall(TaxiNodeGetType,index)
        if ok then return state end
    end
end
function Flights:Database()
    local db=ONE.db and ONE.db.guild
    local char=CharacterKey()
    if not db or not char then return end
    db.flightPoints=db.flightPoints or {}
    db.flightPoints[char]=db.flightPoints[char] or {known={},connections={}}
    return db.flightPoints[char]
end
function Flights:Capture()
    local db=self:Database()
    if not db then return end
    local mapID
    if type(GetTaxiMapID)=='function' then
        local ok,result=pcall(GetTaxiMapID)
        if ok then mapID=result end
    end
    if not mapID then return end
    local nodes
    if C_TaxiMap and type(C_TaxiMap.GetAllTaxiNodes)=='function' then
        local ok,all=pcall(C_TaxiMap.GetAllTaxiNodes,mapID)
        if ok and type(all)=='table' then nodes=all end
    end
    if not nodes and type(NumTaxiNodes)=='function' then
        local ok,count=pcall(NumTaxiNodes)
        if ok and type(count)=='number' and count>0 then
            nodes={}
            for i=1,math.min(count,500) do
                local x,y
                if type(TaxiNodePosition)=='function' then
                    local good,a,b=pcall(TaxiNodePosition,i)
                    if good then x,y=a,b end
                end
                local name
                if type(TaxiNodeName)=='function' then
                    local good,n=pcall(TaxiNodeName,i)
                    if good then name=n end
                end
                nodes[i]={name=name,position=x and y and {x=x,y=y} or nil}
            end
        end
    end
    if not nodes then return end
    local here,reachable,seen={}, {}, 0
    for i,node in ipairs(nodes) do
        local key=NodeKey(node,i)
        local state=State(node,i)
        if key and (state=='CURRENT' or state=='REACHABLE') then
            local saved={name=node.name or key,mapID=mapID}
            if node.position and type(node.position.x)=='number'
                and type(node.position.y)=='number' then
                saved.x,saved.y=node.position.x,node.position.y
            end
            db.known[key]=saved
            if state=='CURRENT' then here[#here+1]=key
            else reachable[#reachable+1]=key end
            seen=seen+1
        end
    end
    -- Exact directed reachability observed on this taxi map, not a claim
    -- that every pair of known flight points connects.
    for _,origin in ipairs(here) do
        db.connections[origin]=db.connections[origin] or {}
        for _,target in ipairs(reachable) do
            db.connections[origin][target]=true
        end
    end
    db.lastMapID=mapID
    self.current=here[1]
    self.captured=seen
end
function Flights:Summary()
    local db=self:Database()
    if not db then return 0,0 end
    local points,connections=0,0
    for _ in pairs(db.known or {}) do points=points+1 end
    for _,destinations in pairs(db.connections or {}) do
        for _ in pairs(destinations) do connections=connections+1 end
    end
    return points,connections
end
-- Returns only *observed* chains of flights. Does not imply that the player
-- can currently reach the first flight master on foot, nor does it estimate
-- flight times. Future ONE_Maps routing will attach validated ground legs.
function Flights:KnownFlightChain(from,to)
    local db=self:Database()
    if not db or not db.known[from] or not db.known[to] then return nil end
    local seen={[from]=true}
    local previous={}
    local queue={from}
    local head=1
    while head<=#queue do
        local current=queue[head]
        head=head+1
        if current==to then
            local route={to}
            while previous[current] do
                current=previous[current]
                table.insert(route,1,current)
            end
            return route
        end
        for destination in pairs((db.connections or {})[current] or {}) do
            if db.known[destination] and not seen[destination] then
                seen[destination]=true
                previous[destination]=current
                queue[#queue+1]=destination
            end
        end
    end
end
function Flights:Initialize()
    local frame=CreateFrame('Frame')
    frame:RegisterEvent('TAXIMAP_OPENED')
    frame:SetScript('OnEvent',function()
        self:Capture()
        if C_Timer and C_Timer.After then C_Timer.After(.25,function() self:Capture() end) end
    end)
end
