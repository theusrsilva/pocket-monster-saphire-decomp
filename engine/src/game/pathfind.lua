-- Alcance de movimento, igual ao jogo original (ROM0:$1A00):
-- custo de entrar numa casa = costs[espécie][terreno]; $63 (99) = intransitável;
-- a unidade gasta até MOV pontos. Validado casa a casa contra o jogo rodando.
local Path = {}

local function key(x, y, cols) return y * cols + x end

-- Retorna mapa key->custo e key->key do passo anterior (para refazer o caminho).
-- blocked(x,y) -> true se a casa tem unidade inimiga (não dá para atravessar).
function Path.reach(stage, costs, unit, blocked)
  local cols, rows = stage.cols, stage.rows
  local row = costs[unit.species] or costs[0]
  local best, prev = {}, {}
  local start = key(unit.x, unit.y, cols)
  best[start] = 0
  -- Dijkstra simples: o grid é pequeno (no máximo 32x32).
  local open = { start }
  while #open > 0 do
    local bi, bk = 1, open[1]
    for i = 2, #open do
      if best[open[i]] < best[bk] then bi, bk = i, open[i] end
    end
    table.remove(open, bi)
    local x, y = bk % cols, math.floor(bk / cols)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, ny = x + d[1], y + d[2]
      if nx >= 0 and ny >= 0 and nx < cols and ny < rows and not blocked(nx, ny) then
        local t = stage.terrain[ny * cols + nx + 1]
        local c = row[t] or 99
        if c < 99 then
          local nc = best[bk] + c
          local nk = key(nx, ny, cols)
          if nc <= unit.move and (best[nk] == nil or nc < best[nk]) then
            if best[nk] == nil then open[#open + 1] = nk end
            best[nk], prev[nk] = nc, bk
          end
        end
      end
    end
  end
  return best, prev
end

function Path.route(prev, cols, fromKey, toKey)
  local steps = {}
  local k = toKey
  while k and k ~= fromKey do
    table.insert(steps, 1, { x = k % cols, y = math.floor(k / cols) })
    k = prev[k]
  end
  return steps
end

function Path.dist(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end

return Path
