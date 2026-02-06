import { useEffect, useCallback } from 'react';
import { useSimulationStore } from '../stores/simulationStore';

export function useKeyboardControls() {
  const {
    setThrottle,
    setSteering,
    setAPoint,
    setBPoint,
    clearGuidance,
    toggleImplement,
    reset,
  } = useSimulationStore();

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      // Ignore if typing in an input
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }

      switch (e.key.toLowerCase()) {
        case 'arrowup':
        case 'w':
          setThrottle(1);
          break;
        case 'arrowdown':
        case 's':
          setThrottle(-1);
          break;
        case 'arrowleft':
        case 'a':
          setSteering(-1);
          break;
        case 'arrowright':
        case 'd':
          setSteering(1);
          break;
        case '1':
          setAPoint();
          break;
        case '2':
          setBPoint();
          break;
        case 'c':
          clearGuidance();
          break;
        case ' ':
          e.preventDefault();
          toggleImplement();
          break;
        case 'r':
          reset();
          break;
      }
    },
    [setThrottle, setSteering, setAPoint, setBPoint, clearGuidance, toggleImplement, reset]
  );

  const handleKeyUp = useCallback(
    (e: KeyboardEvent) => {
      switch (e.key.toLowerCase()) {
        case 'arrowup':
        case 'w':
        case 'arrowdown':
        case 's':
          setThrottle(0);
          break;
        case 'arrowleft':
        case 'a':
        case 'arrowright':
        case 'd':
          setSteering(0);
          break;
      }
    },
    [setThrottle, setSteering]
  );

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, [handleKeyDown, handleKeyUp]);
}
