local CollisionCtR = {
    version = "2.0.0"
}

-- Constants for optimization and consistency
local CONSTANTS = {
    TOLERANCE = 0.001,           -- Floating point tolerance
    TUNNELING_THRESHOLD = 50,    -- Speed threshold for tunneling detection (units/sec)
    BROAD_PHASE_CELL_SIZE = 20,  -- Size of broad-phase grid cells
    MAX_COLLISION_OBJECTS = 50   -- Maximum objects to check in broad phase
}

-- Check collision between circle and rectangle
-- circle = {x, y, radius}
-- rect = {x, y, width, height}
-- Returns: false if no collision, or {closestPoint, distance} if collision
function CollisionCtR:checkCollision(circle, rect)
    if not circle or not rect then
        return false
    end
    
    -- Find the closest point to the circle within the rectangle
    local closestX = math.max(rect.x, math.min(circle.x, rect.x + rect.width))
    local closestY = math.max(rect.y, math.min(circle.y, rect.y + rect.height))
    
    -- Calculate the distance between the circle's center and this closest point
    local distanceX = circle.x - closestX
    local distanceY = circle.y - closestY
    local distanceSquared = (distanceX * distanceX) + (distanceY * distanceY)
    
    -- If the distance is less than the circle's radius, an intersection has occurred
    local isColliding = distanceSquared < (circle.radius * circle.radius)
    
    -- Also check if circle center is inside the rectangle
    if circle.x >= rect.x and circle.x <= rect.x + rect.width and
       circle.y >= rect.y and circle.y <= rect.y + rect.height then
        isColliding = true
    end
    
    if not isColliding then
        return false
    end
    
    return {
        closestPoint = {x = closestX, y = closestY},
        distance = math.sqrt(distanceSquared)
    }
end

-- Check for tunneling between two positions (for high-speed objects)
-- prevCircle = {x, y, radius} - previous position
-- currentCircle = {x, y, radius} - current position
-- rect = {x, y, width, height} - rectangle to check against
-- Returns: false if no tunneling, or {collisionPoint, t} if tunneling occurred
function CollisionCtR:checkTunneling(prevCircle, currentCircle, rect)
    if not prevCircle or not currentCircle or not rect then
        return false
    end
    
    -- Calculate movement vector
    local dx = currentCircle.x - prevCircle.x
    local dy = currentCircle.y - prevCircle.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Skip if movement is too small
    if distance < CONSTANTS.TOLERANCE then
        return false
    end
    
    -- Normalize movement vector
    local nx = dx / distance
    local ny = dy / distance
    
    -- Expand rectangle by circle radius for swept collision
    local expandedRect = {
        x = rect.x - prevCircle.radius,
        y = rect.y - prevCircle.radius,
        width = rect.width + 2 * prevCircle.radius,
        height = rect.height + 2 * prevCircle.radius
    }
    
    -- Check if movement line intersects expanded rectangle
    local t = CollisionCtR:lineRectIntersection(
        prevCircle.x, prevCircle.y, currentCircle.x, currentCircle.y,
        expandedRect.x, expandedRect.y, expandedRect.x + expandedRect.width, expandedRect.y + expandedRect.height
    )
    
    if t and t >= 0 and t <= 1 then
        local collisionX = prevCircle.x + dx * t
        local collisionY = prevCircle.y + dy * t
        return {
            collisionPoint = {x = collisionX, y = collisionY},
            t = t
        }
    end
    
    return false
end

-- Helper function: Check if line segment intersects rectangle
-- Returns: t value (0-1) if intersection, nil otherwise
function CollisionCtR:lineRectIntersection(x1, y1, x2, y2, rx1, ry1, rx2, ry2)
    local dx = x2 - x1
    local dy = y2 - y1
    
    -- Parametric line: p = p1 + t * (p2 - p1)
    local t0 = 0
    local t1 = 1
    
    -- Check horizontal bounds
    if dx ~= 0 then
        local tx1 = (rx1 - x1) / dx
        local tx2 = (rx2 - x1) / dx
        t0 = math.max(t0, math.min(tx1, tx2))
        t1 = math.min(t1, math.max(tx1, tx2))
    elseif x1 < rx1 or x1 > rx2 then
        return nil -- Line is outside rectangle
    end
    
    -- Check vertical bounds
    if dy ~= 0 then
        local ty1 = (ry1 - y1) / dy
        local ty2 = (ry2 - y1) / dy
        t0 = math.max(t0, math.min(ty1, ty2))
        t1 = math.min(t1, math.max(ty1, ty2))
    elseif y1 < ry1 or y1 > ry2 then
        return nil -- Line is outside rectangle
    end
    
    if t0 <= t1 then
        return t0 -- Return first intersection point
    end
    
    return nil
end

-- Broad-phase collision detection for multiple objects at same height
-- circle = {x, y, radius} - the moving circle
-- objects = array of {x, y, width, height, id} - static objects at same height
-- Returns: array of potential collision objects (narrowed down from broad phase)
function CollisionCtR:broadPhaseDetection(circle, objects)
    if not circle or not objects then
        return {}
    end
    
    local potentialCollisions = {}
    local cellSize = CONSTANTS.BROAD_PHASE_CELL_SIZE
    
    -- Calculate circle's grid cell
    local circleCellX = math.floor(circle.x / cellSize)
    local circleCellY = math.floor(circle.y / cellSize)
    
    -- Check objects in same cell and adjacent cells
    for _, obj in ipairs(objects) do
        local objCellX = math.floor(obj.x / cellSize)
        local objCellY = math.floor(obj.y / cellSize)
        
        -- Check if object is in same cell or adjacent cells
        if math.abs(objCellX - circleCellX) <= 1 and math.abs(objCellY - circleCellY) <= 1 then
            -- Quick distance check before detailed collision
            local dx = circle.x - (obj.x + obj.width / 2)
            local dy = circle.y - (obj.y + obj.height / 2)
            local distanceSquared = dx * dx + dy * dy
            local maxDistance = circle.radius + math.max(obj.width, obj.height) / 2
            
            if distanceSquared <= maxDistance * maxDistance then
                table.insert(potentialCollisions, obj)
            end
        end
        
        -- Limit number of objects to check for performance
        if #potentialCollisions >= CONSTANTS.MAX_COLLISION_OBJECTS then
            break
        end
    end
    
    return potentialCollisions
end

-- Calculate exit velocity of ball after collision with moving left or right edge
-- ball = {x, y, radius, vx, vy} - ball position, radius, and velocity
-- edge = {x, vx, isRight} - edge x position, horizontal velocity, and whether it's a right edge
-- Returns: {vx, vy} - new ball velocity after collision
function CollisionCtR:calculateHorizontalEdgeCollisionVelocity(ball, edge)
    if not ball or not edge then
        return {vx = 0, vy = 0}
    end
    
    -- Extract parameters
    local ballX, ballY = ball.x, ball.y
    local ballRadius = ball.radius
    local ballVx, ballVy = ball.vx, ball.vy
    local edgeX = edge.x
    local edgeVx = edge.vx or 0
    local isRight = edge.isRight
    
    -- Check if ball is touching the edge
    local isColliding = isRight and (ballX + ballRadius >= edgeX) or (ballX - ballRadius <= edgeX)
    if not isColliding then
        return {vx = ballVx, vy = ballVy}
    end
    
    -- Set normal direction (right edge: normal points left, left edge: normal points right)
    local normalX = isRight and -1 or 1
    local normalY = 0
    
    -- Calculate relative velocity
    local relativeVx = ballVx - edgeVx
    local relativeVy = ballVy
    
    -- Calculate velocity component along the normal
    local velocityAlongNormal = relativeVx * normalX + relativeVy * normalY
    
    -- For elastic collision, reverse the velocity component along the normal
    local newRelativeVx = relativeVx - 2 * velocityAlongNormal * normalX
    local newRelativeVy = relativeVy - 2 * velocityAlongNormal * normalY
    
    -- Convert back to absolute velocity
    local newBallVx = newRelativeVx + edgeVx
    local newBallVy = newRelativeVy
    
    return {vx = newBallVx, vy = newBallVy}
end

-- Calculate exit velocity of ball after collision with moving top edge
-- ball = {x, y, radius, vx, vy} - ball position, radius, and velocity
-- topEdge = {y, vx} - top edge y position and horizontal velocity
-- Returns: {vx, vy} - new ball velocity after collision
function CollisionCtR:calculateTopEdgeCollisionVelocity(ball, topEdge)
    if not ball or not topEdge then
        return {vx = 0, vy = 0}
    end
    
    -- Extract parameters
    local ballX, ballY = ball.x, ball.y
    local ballRadius = ball.radius
    local ballVx, ballVy = ball.vx, ball.vy
    local edgeY = topEdge.y
    local edgeVx = topEdge.vx or 0
    
    -- Check if ball is touching the top edge
    if ballY - ballRadius > edgeY then
        return {vx = ballVx, vy = ballVy}
    end
    
    -- For top edge collision, normal points down (negative y)
    local normalX = 0
    local normalY = -1
    
    -- Calculate relative velocity
    local relativeVx = ballVx - edgeVx
    local relativeVy = ballVy
    
    -- Calculate velocity component along the normal
    local velocityAlongNormal = relativeVx * normalX + relativeVy * normalY
    
    -- For elastic collision, reverse the velocity component along the normal
    local newRelativeVx = relativeVx - 2 * velocityAlongNormal * normalX
    local newRelativeVy = relativeVy - 2 * velocityAlongNormal * normalY
    
    -- Convert back to absolute velocity
    local newBallVx = newRelativeVx + edgeVx
    local newBallVy = newRelativeVy
    
    return {vx = newBallVx, vy = newBallVy}
end

return CollisionCtR 