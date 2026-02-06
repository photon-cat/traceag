import { useMemo } from 'react';
import { useSimulationStore } from '../../stores/simulationStore';

interface GuidanceBarProps {
  maxError?: number; // Maximum error in meters for full deflection
}

export function GuidanceBar({ maxError = 3 }: GuidanceBarProps) {
  const state = useSimulationStore((s) => s.state);

  const { position, isOnTrack, direction } = useMemo(() => {
    if (!state?.guidance.abLine) {
      return { position: 50, isOnTrack: true, direction: 'center' as const };
    }

    const xte = state.guidance.crossTrackError;
    const clampedError = Math.max(-maxError, Math.min(maxError, xte));
    const normalizedPosition = (clampedError / maxError) * 50 + 50;

    return {
      position: normalizedPosition,
      isOnTrack: Math.abs(xte) < 0.1,
      direction: xte > 0.05 ? 'right' : xte < -0.05 ? 'left' : 'center',
    };
  }, [state?.guidance.crossTrackError, state?.guidance.abLine, maxError]);

  const hasGuidance = !!state?.guidance.abLine;

  return (
    <div className="w-full max-w-md">
      {/* Error value display */}
      <div className="flex justify-between items-center mb-1 text-sm">
        <span className="text-slate-400">L</span>
        <span
          className={`font-mono font-bold ${
            !hasGuidance
              ? 'text-slate-500'
              : isOnTrack
              ? 'text-green-400'
              : 'text-red-400'
          }`}
        >
          {hasGuidance
            ? `${Math.abs(state!.guidance.crossTrackError * 100).toFixed(0)} cm ${direction === 'left' ? 'L' : direction === 'right' ? 'R' : ''}`
            : '-- cm'}
        </span>
        <span className="text-slate-400">R</span>
      </div>

      {/* Guidance bar */}
      <div className="relative h-6 bg-slate-700 rounded-full overflow-hidden">
        {/* Center marker */}
        <div className="absolute left-1/2 top-0 bottom-0 w-0.5 bg-slate-500 -translate-x-1/2" />

        {/* Tick marks */}
        {[25, 75].map((pos) => (
          <div
            key={pos}
            className="absolute top-0 bottom-0 w-px bg-slate-600"
            style={{ left: `${pos}%` }}
          />
        ))}

        {/* Indicator */}
        <div
          className={`absolute top-1 bottom-1 w-3 rounded-full transition-all duration-75 ${
            !hasGuidance
              ? 'bg-slate-500'
              : isOnTrack
              ? 'bg-green-500 shadow-lg shadow-green-500/50'
              : 'bg-red-500 shadow-lg shadow-red-500/50'
          }`}
          style={{
            left: `${position}%`,
            transform: 'translateX(-50%)',
          }}
        />

        {/* Direction arrows when off track */}
        {hasGuidance && !isOnTrack && (
          <>
            {direction === 'left' && (
              <div className="absolute right-2 top-1/2 -translate-y-1/2 text-red-400 animate-pulse">
                {'>>>'}
              </div>
            )}
            {direction === 'right' && (
              <div className="absolute left-2 top-1/2 -translate-y-1/2 text-red-400 animate-pulse">
                {'<<<'}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
