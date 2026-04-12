# UX Guidelines

## Essential

- Clear unit selection feedback
- Visible movement commands
- Smooth camera controls
- Immediate client feedback for accepted input

## Camera

- WASD movement or edge scrolling
- Zoom in/out (optional)

## Feedback

- Highlight selected units
- Show target position
- Immediate response to input

## Principle

Game must feel responsive from early stage.

## Client vs Simulation Split

- Camera, selection, hover, and indicators belong to client state
- These client features may update immediately for responsiveness
- Immediate feedback must not mutate authoritative `GameState`
- Authoritative gameplay changes occur only on simulation ticks
- Movement may render smoothly on client, but authoritative position stays grid-backed
