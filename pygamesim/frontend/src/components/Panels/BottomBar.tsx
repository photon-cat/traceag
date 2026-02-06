import { useSimulationStore } from '../../stores/simulationStore';

export function BottomBar() {
  const state = useSimulationStore((s) => s.state);
  const implementActive = state?.implement.active || false;

  return (
    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-10">
      <div className="panel px-6 py-3 flex items-center gap-6">
        {/* Rate indicator */}
        <div className="flex items-center gap-3">
          <div
            className={`w-10 h-10 rounded-lg flex items-center justify-center ${
              implementActive ? 'bg-blue-600' : 'bg-slate-600'
            }`}
          >
            <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71z" />
            </svg>
          </div>
          <div>
            <div className="text-sm text-slate-400">Rate - Corn Post Emerge</div>
            <div className="flex items-center gap-4 text-sm">
              <span>4</span>
              <span>8</span>
              <span className="font-bold text-blue-400">12</span>
              <span>16</span>
            </div>
          </div>
        </div>

        {/* Vertical divider */}
        <div className="w-px h-10 bg-slate-600" />

        {/* Drive controls hint */}
        <div className="text-sm text-slate-400">
          <div className="flex items-center gap-2">
            <kbd className="px-2 py-1 bg-slate-700 rounded text-xs">W</kbd>
            <kbd className="px-2 py-1 bg-slate-700 rounded text-xs">A</kbd>
            <kbd className="px-2 py-1 bg-slate-700 rounded text-xs">S</kbd>
            <kbd className="px-2 py-1 bg-slate-700 rounded text-xs">D</kbd>
            <span className="ml-2">or Arrow Keys to drive</span>
          </div>
        </div>
      </div>
    </div>
  );
}
