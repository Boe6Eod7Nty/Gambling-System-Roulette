local CollisionCtR = {
    version = "1.0.0"
}

-- Check collision between circle and rectangle
-- circle = {x, y, radius}
-- rect = {x, y, width, height}
-- Returns: false if no collision, or {closestPoint, closestCorner} if collision
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
    
    -- If the distance is less than the circle's radius, an intersection has occurred
    local distanceSquared = (distanceX * distanceX) + (distanceY * distanceY)
    local isColliding = distanceSquared < (circle.radius * circle.radius)
    
    -- Also check if circle center is inside the rectangle
    if circle.x >= rect.x and circle.x <= rect.x + rect.width and
       circle.y >= rect.y and circle.y <= rect.y + rect.height then
        isColliding = true
    end
    
    if not isColliding then
        return false
    end
    
    -- Find the closest corner
    local corners = {
        {x = rect.x, y = rect.y}, -- top-left
        {x = rect.x + rect.width, y = rect.y}, -- top-right
        {x = rect.x + rect.width, y = rect.y + rect.height}, -- bottom-right
        {x = rect.x, y = rect.y + rect.height} -- bottom-left
    }
    
    local closestCorner = corners[1]
    local minDistance = (circle.x - corners[1].x)^2 + (circle.y - corners[1].y)^2
    
    for i = 2, 4 do
        local dist = (circle.x - corners[i].x)^2 + (circle.y - corners[i].y)^2
        if dist < minDistance then
            minDistance = dist
            closestCorner = corners[i]
        end
    end
    
    return {
        closestPoint = {x = closestX, y = closestY},
        closestCorner = closestCorner
    }
end

-- Check the position of closest point relative to rectangle
-- closest = {x, y} - the closest point to the circle within the rectangle
-- topLeft = {x, y} - the top-left corner of the rectangle
-- corner = {x, y} - the closest corner to the circle
-- Returns: "corner", "top", "left", or "right"
function CollisionCtR:checkClosestPosition(closest, topLeft, corner)
    if not closest or not topLeft or not corner then
        return "unknown"
    end
    
    -- Check if closest and corner are equal (tolerance for floating point)
    local tolerance = 0.001
    if math.abs(closest.x - corner.x) < tolerance and math.abs(closest.y - corner.y) < tolerance then
        return "corner"
    end
    
    -- Check if y coordinates match (top or bottom edge)
    if math.abs(closest.y - topLeft.y) < tolerance then
        return "top"
    end
    
    -- Check if x coordinates match (left edge)
    if math.abs(closest.x - topLeft.x) < tolerance then
        return "left"
    end
    
    -- Otherwise it's on the right side
    return "right"
end

-- Alternative function for more precise corner collision detection
-- This version handles the case where the ball hits exactly at the corner point
function CollisionCtR:calculatePreciseCornerCollisionVelocity(ball, corner)
    if not ball or not corner then
        return {vx = 0, vy = 0}
    end
    
    -- Extract parameters
    local ballX, ballY = ball.x, ball.y
    local ballRadius = ball.radius
    local ballVx, ballVy = ball.vx, ball.vy
    local cornerX, cornerY = corner.x, corner.y
    local cornerVx = corner.vx or 0
    
    -- Calculate distance from ball center to corner
    local dx = ballX - cornerX
    local dy = ballY - cornerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- If ball is not touching the corner, return original velocity
    if distance > ballRadius then
        return {vx = ballVx, vy = ballVy}
    end
    
    -- Calculate collision normal (from corner to ball center)
    local normalX = dx / distance
    local normalY = dy / distance
    
    -- Calculate relative velocity
    local relativeVx = ballVx - cornerVx
    local relativeVy = ballVy
    
    -- Calculate velocity component along the normal
    local velocityAlongNormal = relativeVx * normalX + relativeVy * normalY
    
    -- For elastic collision, reverse the velocity component along the normal
    local newRelativeVx = relativeVx - 2 * velocityAlongNormal * normalX
    local newRelativeVy = relativeVy - 2 * velocityAlongNormal * normalY
    
    -- Convert back to absolute velocity
    local newBallVx = newRelativeVx + cornerVx
    local newBallVy = newRelativeVy
    
    return {vx = newBallVx, vy = newBallVy}
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