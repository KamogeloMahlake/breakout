Powerup = Class{}
BALLS = 9
KEY = 10

function Powerup:init(x, y, type)
  self.x = x
  self.y = y
  self.type = type
  self.width = 16
  self.height = 16
  self.dy = math.random(20, 50)
  self.onScreen = true
end
--[[
  Returns true if paddle(target) and Powerup overlap else false
]]
function Powerup:collides(target)
  if self.x > target.x + target.width or target.x > self.x + self.width then
    return false
  end

  if self.y > target.y + target.height or target.y > self.y + self.height then
    return false
  end
  return true
end
--[[
    Moves powerup down based on dt
]]
function Powerup:update(dt)
  self.y = self.y + self.dy * dt
  if self.y >= VIRTUAL_HEIGHT then
    self.onScreen = false
  end
end

--[[
    Draws the powerup if still onScreen
]]
function Powerup:render()
  if self.onScreen then
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], self.x, self.y)
  end
end
