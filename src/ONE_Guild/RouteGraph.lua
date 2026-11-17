-- ONE 0.3.7c: original, dependency-free, data-driven routing core.
-- IMPORTANT: An edge must be backed by verified walkable terrain or an
-- actually usable transport connection. Empty graph is intentional: a
-- straight line across unknown terrain MUST NOT be sold as a real route.
local _, guild = ...
local Graph = {}
guild.RouteGraph = Graph

function Graph:New()
    return setmetatable({ nodes = {}, edges = {}, taxiAvailable = {} }, {__index = self})
end
function Graph:AddNode(id, mapID, x, y, label)
    if type(id) ~= 'string' or not id:match('%S')
        or type(mapID) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number'
        or x < 0 or x > 1 or y < 0 or y > 1 then return false end
    self.nodes[id] = {id=id, mapID=mapID, x=x, y=y, label=label or id}
    self.edges[id] = self.edges[id] or {}
    return true
end
function Graph:AddEdge(from, to, mode, seconds, bidirectional)
    if not self.nodes[from] or not self.nodes[to]
        or (mode ~= 'walk' and mode ~= 'taxi' and mode ~= 'transport')
        or type(seconds) ~= 'number' or seconds <= 0 then return false end
    self.edges[from][#self.edges[from]+1] = {to=to, mode=mode, seconds=seconds}
    if bidirectional then self:AddEdge(to, from, mode, seconds, false) end
    return true
end
function Graph:AllowTaxi(from, to)
    if self.nodes[from] and self.nodes[to] then
        self.taxiAvailable[from] = self.taxiAvailable[from] or {}
        self.taxiAvailable[from][to] = true
    end
end
-- Min-heap: O((V+E) log V), suitable for a future large road graph.
local function Push(heap,id,cost)
    local i=#heap+1
    while i>1 do
        local parent=math.floor(i/2)
        local item=heap[parent]
        if item.cost<=cost then break end
        heap[i]=item
        i=parent
    end
    heap[i]={id=id,cost=cost}
end
local function Pop(heap)
    local n=#heap
    if n==0 then return end
    local first=heap[1]
    local last=heap[n]
    heap[n]=nil
    n=n-1
    if n>0 then
        local i=1
        while i*2<=n do
            local child=i*2
            if child+1<=n and heap[child+1].cost<heap[child].cost then
                child=child+1
            end
            if last.cost<=heap[child].cost then break end
            heap[i]=heap[child]
            i=child
        end
        heap[i]=last
    end
    return first.id,first.cost
end
function Graph:Find(from, to)
    if not self.nodes[from] or not self.nodes[to] then return nil, 'missing-data' end
    -- Dijkstra (A* with admissible h = 0): different transport types cannot
    -- safely use a spatial heuristic without a verified global speed bound.
    local best, previous, closed = {[from]=0}, {}, {}
    local queue={}
    Push(queue,from,0)
    local visited=0
    while #queue>0 do
        local current,cost=Pop(queue)
        if not closed[current] and cost==best[current] then
            visited=visited+1
            if visited>50000 then return nil,'too-many-nodes' end
            if current==to then
                local legs, cursor={},to
                while previous[cursor] do
                    local p=previous[cursor]
                    table.insert(legs,1,{from=p.from,to=cursor,mode=p.edge.mode,
                        seconds=p.edge.seconds,target=self.nodes[cursor]})
                    cursor=p.from
                end
                return {seconds=cost,legs=legs}
            end
            closed[current]=true
            for _,edge in ipairs(self.edges[current] or {}) do
                local allowed=edge.mode~='taxi' or
                    (self.taxiAvailable[current] and self.taxiAvailable[current][edge.to])
                if allowed and not closed[edge.to] then
                    local nextCost=cost+edge.seconds
                    if not best[edge.to] or nextCost<best[edge.to] then
                        best[edge.to]=nextCost
                        previous[edge.to]={from=current,edge=edge}
                        Push(queue,edge.to,nextCost)
                    end
                end
            end
        end
    end
    return nil,'unreachable'
end
