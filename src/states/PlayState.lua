--[[
    CS50 2D
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = { params.ball }
    self.level = params.level
    self.powerups = {
        [BALLS] = {},
        [KEY] = nil
    }
    self.ballsTimer = 0
    self.ballsInterval = math.random(8, 15)
    self.keyTimer = 0
    self.keyInterval = math.random(6, 12)
    self.hasKey = false

    self.recoverPoints = params.recoverPoints

    -- give ball random starting velocity
    params.ball.dx = math.random(-200, 200)
    params.ball.dy = math.random(-50, -60)
end

function PlayState:spawnPowerup(dt)
  self.ballsTimer = self.ballsTimer + dt
  self.keyTimer = self.keyTimer + dt

  if self.ballsTimer >= self.ballsInterval then
    self.ballsTimer = 0
    self.ballsInterval = math.random(8, 15)
    table.insert(self.powerups[BALLS], Powerup(math.random(0, VIRTUAL_WIDTH - 16), -16, BALLS))
  end

  if self.keyTimer >= self.keyInterval then
    self.keyTimer = 0
    self.keyInterval = math.random(6, 12)
    local l = false
    for _, brick in pairs(self.bricks) do
      if brick.locked then
        l = true
      end
    end

    if l and not self.hasKey and self.powerups[KEY] == nil then
      self.powerups[KEY] = Powerup(math.random(0, VIRTUAL_WIDTH - 16), -16, KEY)
    end
  end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end



    -- update positions based on velocity
    self.paddle:update(dt)
    self:spawnPowerup(dt)
    for i = #self.balls, 1, -1 do
      self.balls[i]:update(dt)

      if not self.balls[i].inPlay and #self.balls > 1 then
        table.remove(self.balls, i)
      end
    end

    if self.powerups[KEY] then
      self.powerups[KEY]:update(dt)

      if not self.powerups[KEY].onScreen then
        self.powerups[KEY] = nil
      elseif self.powerups[KEY]:collides(self.paddle) then
        self.hasKey = true
        self.powerups[KEY] = nil
      end
    end

    for i = #self.powerups[BALLS], 1, -1 do
      self.powerups[BALLS][i]:update(dt)

      if not self.powerups[BALLS][i].onScreen then
        table.remove(self.powerups[BALLS], i)
      end
    end

    for _, ball in pairs(self.balls) do
      if ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
          ball.y = self.paddle.y - 8
          ball.dy = -ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

          local isPaddleMovingLeft = self.paddle.dx < 0
          local isPaddleMovingRight = self.paddle.dx > 0
          local paddleCenter = self.paddle.x + self.paddle.width / 2

        -- adjustable values for the feel of bounce speed/angle
          local startingBounceDX = 50
          local bounceAngleMultiplier = 8

        -- if we hit the paddle on its left side while moving left...
          if ball.x < paddleCenter and isPaddleMovingLeft then
              local ballOffset = paddleCenter - ball.x
              ball.dx = -startingBounceDX - bounceAngleMultiplier * ballOffset

        -- else if we hit the paddle on its right side while moving right...
          elseif ball.x > paddleCenter and isPaddleMovingRight then
              local ballOffset = ball.x - paddleCenter
              ball.dx = startingBounceDX + bounceAngleMultiplier * ballOffset
          end

          gSounds['paddle-hit']:play()
      end
    end

    -- detect collision across all bricks with the ball
    for _, ball in pairs(self.balls) do
      for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay and ball:collides(brick) then
          if not brick.locked then

            -- add to score
            self.score = self.score + (brick.tier * 200 + brick.color * 25)

            -- trigger the brick's hit function, which removes it from play
            brick:hit()
            if self.score >= self.paddle.nextGrow then
              self.paddle:grow()
              self.paddle.nextGrow = self.paddle.nextGrow + 1500
            end

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                -- play recover sound effect
                gSounds['recover']:play()
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = ball,
                    recoverPoints = self.recoverPoints,

                })
            end
          elseif brick.locked and self.hasKey then
            brick.locked = false
            self.score = self.score + 1500
            self.hasKey = false
          end

            --
            -- collision code for bricks
            --
            -- we check to see how much we overlap on the brick between X and Y axes;
            -- the delta between the centers of the brick and ball will help us pinpoint
            -- which side, and then how far in the ball has overlapped will determine
            -- whether to prioritize a Y bounce or an X bounce

            local BALL_RADIUS = 4
            local BRICK_W, BRICK_H = brick.width, brick.height

            -- centers of X and Y of our brick and ball
            local cxB, cyB = brick.x + BRICK_W / 2, brick.y + BRICK_H / 2
            local cxb, cyb = ball.x + BALL_RADIUS, ball.y + BALL_RADIUS

            -- signed collision offsets between brick and ball
            local ox = cxB - cxb
            local oy = cyB - cyb

            -- penetration depth of the ball on X and Y;
            -- add half-extents of brick and ball, then subtract
            -- amount of overlap on that axis; the higher penetration
            -- depth is the prioritized collision and axis of bounce
            local px = BRICK_W / 2 + BALL_RADIUS - math.abs(ox)
            local py = BRICK_H / 2 + BALL_RADIUS - math.abs(oy)

            if px < py then
                ball.dx = -ball.dx
                ball.x = ball.x + (ox > 0 and -px or px)
            else
                ball.dy = -ball.dy
                ball.y = ball.y + (oy > 0 and -py or py)
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(ball.dy) < 150 then
                ball.dy = ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
      end
    end


    for i = #self.powerups[BALLS], 1, -1 do
      if self.powerups[BALLS][i]:collides(self.paddle) then
        table.remove(self.powerups[BALLS], i)
        local ball = Ball(math.random(7))
        ball.x = self.paddle.x + self.paddle.width / 2 - 4
        ball.y = self.paddle.y - 8
        ball.dx = math.random(-200, 200)
        ball.dy = math.random(-50, -60)
        table.insert(self.balls, ball)
      end
    end

    for _, ball in pairs(self.balls) do
    -- if ball goes below bounds, revert to serve state and decrease health
      if ball.y >= VIRTUAL_HEIGHT then
        self.health = self.health - 1
        self.paddle:shrink()
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            gStateMachine:change('serve', {
                paddle = self.paddle,
                bricks = self.bricks,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints,
            })
        end
      end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    for _, ball in pairs(self.balls) do
      ball:render()
    end

    for _, pu in pairs(self.powerups[BALLS]) do
      pu:render()
    end

    if self.powerups[KEY] then
      self.powerups[KEY]:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
