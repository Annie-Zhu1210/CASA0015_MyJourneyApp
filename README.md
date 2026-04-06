# MyJourney

# Design Summary

## Exploration Path

The Exploration Path is a "fog of war" effect layered on top of the Google Maps view. The entire map is dimmed to 50% brightness by default. As the user moves around in the real world, small circular areas centred on their visited locations are revealed at full brightness. The result is a visual record of everywhere the user has been, with unvisited areas remaining dark.


### Design Details

**Unvisited areas**: covered by a black overlay at 50% opacity, giving a dimmed appearance
**Visited areas**: the overlay is punched through with transparent circles, restoring the full-brightness map underneath
**Circle radius**: 50 metres around each recorded GPS point
**Recording interval**: a new point is saved every 30 metres of movement
**Edge treatment**: each circle has a soft feathered edge using 8 concentric rings of decreasing opacity, giving a natural glowing look rather than a hard cutout
**Persistence**: all visited points are saved to local device storage using `shared_preferences`, so the exploration history survives app restarts

### How It Works

#### Data Layer — `ExplorationService`
- Visited locations are stored as a list of `VisitedPoint` objects (latitude/longitude pairs)
- On each GPS update, a Haversine distance check determines whether the new point is at least 30 metres from all existing points before saving
- The full list is serialised to JSON and written to `SharedPreferences` on every new point added
- On app launch, the saved list is loaded back before the map initialises

#### Rendering Layer — `ExplorationPathPainter`
- A `CustomPainter` sits in a `Positioned.fill` widget on top of the `GoogleMap` widget, wrapped in `IgnorePointer` so it doesn't intercept map touch events
- `canvas.saveLayer()` is called first — this is required for `BlendMode.clear` to work correctly
- The full canvas is filled with `Colors.black` at 50% alpha
- For each visited point, `BlendMode.clear` removes the fog pixels within the circle radius, making those pixels fully transparent and revealing the map below
- Screen pixel positions for each visited point are obtained via `GoogleMapController.getScreenCoordinate()`, which asks the native map layer for the exact pixel location of each lat/lng coordinate

#### Coordinate Updates
- Screen positions are recomputed by calling `getScreenCoordinate` for every visited point whenever `onCameraIdle` fires (i.e. when the user stops panning or zooming)
- During active dragging, the overlay stays frozen in its last known position

### The Core Trade-off

The fundamental tension is between **accuracy** and **responsiveness**:

- **`getScreenCoordinate` (async, accurate)**: Asking Google Maps itself for the screen position of each lat/lng gives pixel-perfect results, because it uses the map's internal projection including all device-specific offsets. However, it requires a round-trip across the Flutter-to-native bridge for every visited point, which takes time and cannot be called synchronously during active panning.

- **Custom Mercator maths (synchronous, potentially inaccurate)**: Computing positions ourselves in pure Dart is instant and could update on every single camera frame. However, getting the pixel offset exactly right is surprisingly difficult on iOS due to the interaction between device pixel ratio, safe area insets, app bar height, and Flutter's logical pixel system. Every attempt produced circles that were slightly or significantly offset from the correct position.

#### Final Decision
The current implementation uses `getScreenCoordinate` for accuracy, called only on `onCameraIdle`. During active dragging the overlay freezes in its last good position, then snaps back to the correct place when the user releases. This is a deliberate compromise — correct positions at rest, with a brief freeze during drag — rather than incorrect positions that track the drag smoothly.
