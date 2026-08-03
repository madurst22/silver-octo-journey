-- ============================================================================
-- Latency simulator.
--
-- The whole lab runs on localhost, so without this every response would come
-- back in microseconds and the difference between a cache HIT and a cache MISS
-- would be invisible. This module sleeps for a percentile-distributed number
-- of milliseconds before returning, which makes the cost of a MISS feel real.
--
-- Two profiles are exposed:
--   profiles.backend -- the origin's latency: P50 ~100-400ms, P99 up to 3s.
--                       Mimics a real origin under load (slow-ish median plus
--                       a long tail). Used by lua/origin.lua.
--   profiles.edge    -- the shape an edge cache would have if we modelled it
--                       (P50 1-20ms, P99 up to 500ms). Not wired up in this
--                       lab; kept here for reference.
--
-- Side effect: each call also writes X-Simulated-Latency-Ms to the response
-- headers so a curl -i shows you exactly how long the simulated work took.
-- ============================================================================

local simulations = {}
local random = math.random
local sleep = ngx.sleep
local second = 0.001

math.randomseed(ngx.time() + ngx.worker.pid())

simulations.for_work_longtail = function(percentiles)
  table.sort(percentiles, function(a, b) return a.p < b.p end)

  local roll = random(1, 100)
  local min_wait_ms = 1
  local max_wait_ms = 1000

  for _, percentile in pairs(percentiles) do
    if roll <= percentile.p then
      min_wait_ms = percentile.min
      max_wait_ms = percentile.max
      break
    end
  end

  local sleep_seconds = random(min_wait_ms, max_wait_ms) * second
  ngx.header["X-Simulated-Latency-Ms"] = string.format("%d", sleep_seconds * 1000)
  sleep(sleep_seconds)
end

simulations.profiles = {
  edge = {
    {p = 50, min = 1,   max = 20},
    {p = 90, min = 21,  max = 50},
    {p = 95, min = 51,  max = 150},
    {p = 99, min = 151, max = 500},
  },
  backend = {
    {p = 50, min = 100, max = 400},
    {p = 90, min = 401, max = 500},
    {p = 95, min = 501, max = 1500},
    {p = 99, min = 1501, max = 3000},
  },
}

return simulations
