# Coding Rules

## General

- Max file length: 300 lines
- Functions < 50 lines
- Use clear naming
- Add docstrings to all classes/functions

## Architecture

- No global mutable state
- Systems operate on GameState
- Rendering must not change logic

## Code Quality

- Prefer simple solutions
- Avoid premature abstraction
- Keep dependencies minimal

## Testing

- Each module must include example usage
- Code must run after each step