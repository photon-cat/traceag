# AgGuidance Web UI

Browser-based UI for the pygamesim agricultural guidance simulator.

## Architecture

```
┌─────────────────────┐     WebSocket     ┌──────────────────────┐
│   Python Backend    │ ◄──────────────► │   React Frontend      │
│   (FastAPI)         │    60Hz state     │   (Three.js + R3F)    │
│                     │                   │                       │
│  - Vehicle sim      │                   │  - 3D field view      │
│  - Localizer        │                   │  - Guidance HUD       │
│  - Guidance         │                   │  - Control panels     │
└─────────────────────┘                   └──────────────────────┘
```

## Quick Start

### 1. Install Python dependencies

```bash
cd pygamesim
pip install -r web/requirements.txt
```

### 2. Install frontend dependencies

```bash
cd frontend
npm install
```

### 3. Start the backend server

```bash
# From the traceag directory
python -m pygamesim.web.server
```

Server runs at http://localhost:8000

### 4. Start the frontend dev server

```bash
cd frontend
npm run dev
```

Frontend runs at http://localhost:3000

## Controls

| Key | Action |
|-----|--------|
| W / ↑ | Accelerate forward |
| S / ↓ | Brake/Reverse |
| A / ← | Steer left |
| D / → | Steer right |
| Space | Toggle implement (spray) |
| 1 | Set A point |
| 2 | Set B point |
| C | Clear guidance line |
| R | Reset simulation |

## Tech Stack

- **Backend**: Python, FastAPI, WebSocket
- **Frontend**: React, TypeScript, Vite
- **3D**: Three.js, React Three Fiber
- **Styling**: Tailwind CSS
- **State**: Zustand

## Building for Production

```bash
cd frontend
npm run build
```

The built files will be in `frontend/dist/`. These can be served by the FastAPI backend or any static file server.
