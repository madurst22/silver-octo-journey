-- ============================================================================
-- Origin "service" — step 5 variant.
--
-- Same idea as the earlier-step origin.lua (sleep, return JSON), with two
-- new fault-injection knobs the resilience demos use to simulate outages
-- without stopping containers:
--
--   ?fail=1   -- origin returns 503 immediately (no body sleep). Triggers
--                proxy_cache_use_stale http_503 on the edge => Demo B.
--
--   ?slow=N   -- origin sleeps an extra N seconds before responding.
--                Combined with the edge's proxy_read_timeout 2s, this is
--                how Demo A creates a fake "hung upstream."
--
-- The body now also carries an "origin" field (the container's hostname),
-- which is the smoking gun that proves Demo C's failover landed on origin-b.
--
-- Default Cache-Control max-age is shorter here (5s instead of 15s) so the
-- demos can warm the cache, wait for expiry, and trigger STALE inside one
-- terminal session.
-- ============================================================================

local simulations = require "simulations"
local origin = {}

local function json_escape(value)
  return value:gsub("\\", "\\\\"):gsub('"', '\\"')
end

function origin.respond()
  if ngx.var.arg_fail == "1" then
    ngx.status = 503
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"service":"origin","error":"origin is sick","origin":"' .. (ngx.var.hostname or "unknown") .. '"}')
    return ngx.exit(503)
  end

  local extra_slow = tonumber(ngx.var.arg_slow)
  if extra_slow and extra_slow > 0 then
    ngx.sleep(extra_slow)
  end

  simulations.for_work_longtail(simulations.profiles.backend)

  local path = json_escape(ngx.var.uri or "/")
  local origin_name = json_escape(ngx.var.hostname or "unknown")
  local generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local max_age = ngx.var.arg_max_age or 5

  ngx.header["Content-Type"] = "application/json"
  ngx.header["Cache-Control"] = "public, max-age=" .. max_age

  ngx.say(string.format(
    '{"service":"origin","app":"BuzzStream","origin":"%s","path":"%s","generated_at":"%s","message":"Fresh from the origin server."}',
    origin_name,
    path,
    generated_at
  ))
end

return origin
