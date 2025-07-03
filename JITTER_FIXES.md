# Roulette Spinner Jitter Fixes

## Root Causes Identified

The jitter in the roulette spinner was caused by several issues:

1. **Variable Delta Time (dt)**: The physics calculations used variable `dt` which changes between frames, causing inconsistent movement speeds.

2. **Time-Based Block Movement**: Block positions were calculated using accumulated `dt` values, leading to drift and timing errors.

3. **Frequent Entity Teleportation**: The ball and spinner entities were teleported every frame, causing visual jitter.

4. **Inconsistent Rotation Interpolation**: Spinner rotation used variable `dt` for interpolation, causing jerky movement.

## Solutions Implemented

### 1. Fixed Timestep Physics
- **What**: Physics now runs at a fixed 60 FPS (0.016667 seconds per step)
- **Why**: Ensures consistent movement regardless of frame rate variations
- **How**: Uses a time accumulator that processes physics in fixed steps

### 2. Reduced Entity Update Frequency
- **What**: Entity positions are updated every 3 frames instead of every frame
- **Why**: Reduces visual jitter from frequent teleportation
- **How**: Separated entity updates from physics calculations

### 3. Improved Rotation Smoothing
- **What**: Smoother rotation interpolation using a configurable smoothing factor
- **Why**: Eliminates jerky spinner movement
- **How**: Uses linear interpolation with angle wrapping

### 4. Time-Based Block Positioning
- **What**: Block positions are calculated using fixed timestep instead of variable dt
- **Why**: Maintains perfect spacing between blocks
- **How**: Uses `frameCounter * FIXED_TIMESTEP` for consistent timing

## New Configuration Options

### Rotation Smoothing Factor
- **Default**: 0.1 (smooth)
- **Range**: 0.01 to 1.0
- **Lower values**: Smoother but slower response
- **Higher values**: Faster response but potentially more jitter

### Entity Update Interval
- **Default**: 3 frames
- **Effect**: Higher values reduce jitter but may make movement less responsive

## How to Use

### Testing Different Smoothing Factors
1. Load the spinner (DevHotkey1)
2. Start simulation (DevHotkey2)
3. Press DevHotkey5 to cycle through smoothing values:
   - 0.05: Very smooth, slow response
   - 0.1: Smooth (default)
   - 0.2: Moderate smoothing
   - 0.5: Less smoothing, faster response
   - 1.0: No smoothing, instant response

### Manual Smoothing Adjustment
```lua
-- Set custom smoothing factor
spinner:setRotationSmoothing(0.15)

-- Get current smoothing factor
local current = spinner:getRotationSmoothing()
```

## Performance Impact

- **Fixed timestep**: Slightly more CPU usage but much more consistent
- **Reduced entity updates**: Lower CPU usage and less jitter
- **Overall**: Better visual quality with minimal performance cost

## Troubleshooting

### If spinner still jitters:
1. Try a lower smoothing factor (0.05-0.1)
2. Increase entity update interval in constants
3. Check if frame rate is very low (< 30 FPS)

### If spinner is too slow to respond:
1. Try a higher smoothing factor (0.2-0.5)
2. Decrease entity update interval in constants

### If blocks drift from positions:
1. The fixed timestep should prevent this
2. Check if `FIXED_TIMESTEP` constant is appropriate for your frame rate 