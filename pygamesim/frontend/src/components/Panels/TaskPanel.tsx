import { useEffect, useState } from 'react';
import { useISOXMLStore } from '../../stores/isoxmlStore';

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-gray-500',
  in_progress: 'bg-blue-500',
  paused: 'bg-yellow-500',
  completed: 'bg-green-500',
  cancelled: 'bg-red-500',
};

const TASK_TYPES = [
  'planting',
  'spraying',
  'fertilizing',
  'harvesting',
  'tillage',
  'seeding',
  'mowing',
  'scouting',
  'other',
];

export function TaskPanel() {
  const {
    farms,
    partfields,
    tasks,
    selectedFarmId,
    selectedPartfieldId,
    selectedTaskId,
    loading,
    error,
    selectFarm,
    selectPartfield,
    selectTask,
    setup,
    fetchAll,
    createPartfield,
    createTask,
    updateTaskStatus,
    deleteTask,
    importFile,
    exportData,
  } = useISOXMLStore();

  const [showNewPartfield, setShowNewPartfield] = useState(false);
  const [showNewTask, setShowNewTask] = useState(false);
  const [newPartfieldName, setNewPartfieldName] = useState('');
  const [newTaskName, setNewTaskName] = useState('');
  const [newTaskType, setNewTaskType] = useState('other');

  useEffect(() => {
    setup();
  }, []);

  const handleCreatePartfield = async () => {
    if (selectedFarmId && newPartfieldName.trim()) {
      await createPartfield(selectedFarmId, newPartfieldName.trim());
      setNewPartfieldName('');
      setShowNewPartfield(false);
    }
  };

  const handleCreateTask = async () => {
    if (selectedPartfieldId && newTaskName.trim()) {
      await createTask(selectedPartfieldId, newTaskName.trim(), newTaskType);
      setNewTaskName('');
      setShowNewTask(false);
    }
  };

  const handleExport = async () => {
    try {
      const blob = await exportData(selectedFarmId || undefined);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'TASKDATA.ZIP';
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Export failed:', e);
    }
  };

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      await importFile(file);
      e.target.value = '';
    }
  };

  const selectedPartfield = partfields.find((p) => p.id === selectedPartfieldId);
  const selectedTask = tasks.find((t) => t.id === selectedTaskId);

  return (
    <div className="absolute top-4 left-4 w-80 bg-black/70 backdrop-blur rounded-lg p-4 text-white text-sm">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-bold text-lg">ISOXML Tasks</h2>
        <div className="flex gap-2">
          <label className="cursor-pointer px-2 py-1 bg-blue-600 rounded text-xs hover:bg-blue-700">
            Import
            <input
              type="file"
              accept=".zip,.xml"
              onChange={handleImport}
              className="hidden"
            />
          </label>
          <button
            onClick={handleExport}
            className="px-2 py-1 bg-green-600 rounded text-xs hover:bg-green-700"
          >
            Export
          </button>
        </div>
      </div>

      {loading && <div className="text-center text-gray-400 py-2">Loading...</div>}
      {error && <div className="text-red-400 text-xs mb-2">{error}</div>}

      {/* Farm Selection */}
      <div className="mb-4">
        <label className="block text-xs text-gray-400 mb-1">Farm</label>
        <select
          value={selectedFarmId || ''}
          onChange={(e) => selectFarm(e.target.value || null)}
          className="w-full bg-gray-800 rounded px-2 py-1 text-sm"
        >
          <option value="">Select Farm...</option>
          {farms.map((f) => (
            <option key={f.id} value={f.id}>
              {f.name}
            </option>
          ))}
        </select>
      </div>

      {/* Partfield Selection */}
      {selectedFarmId && (
        <div className="mb-4">
          <div className="flex items-center justify-between mb-1">
            <label className="text-xs text-gray-400">Field</label>
            <button
              onClick={() => setShowNewPartfield(!showNewPartfield)}
              className="text-xs text-blue-400 hover:text-blue-300"
            >
              + New Field
            </button>
          </div>

          {showNewPartfield && (
            <div className="flex gap-2 mb-2">
              <input
                type="text"
                value={newPartfieldName}
                onChange={(e) => setNewPartfieldName(e.target.value)}
                placeholder="Field name"
                className="flex-1 bg-gray-800 rounded px-2 py-1 text-sm"
              />
              <button
                onClick={handleCreatePartfield}
                className="px-2 py-1 bg-green-600 rounded text-xs"
              >
                Add
              </button>
            </div>
          )}

          <select
            value={selectedPartfieldId || ''}
            onChange={(e) => selectPartfield(e.target.value || null)}
            className="w-full bg-gray-800 rounded px-2 py-1 text-sm"
          >
            <option value="">Select Field...</option>
            {partfields.map((pf) => (
              <option key={pf.id} value={pf.id}>
                {pf.name} {pf.area_hectares ? `(${pf.area_hectares.toFixed(1)} ha)` : ''}
              </option>
            ))}
          </select>

          {selectedPartfield && selectedPartfield.boundary && (
            <div className="mt-1 text-xs text-gray-400">
              {selectedPartfield.boundary.length} boundary points
            </div>
          )}
        </div>
      )}

      {/* Tasks */}
      {selectedPartfieldId && (
        <div>
          <div className="flex items-center justify-between mb-2">
            <label className="text-xs text-gray-400">Tasks</label>
            <button
              onClick={() => setShowNewTask(!showNewTask)}
              className="text-xs text-blue-400 hover:text-blue-300"
            >
              + New Task
            </button>
          </div>

          {showNewTask && (
            <div className="bg-gray-800 rounded p-2 mb-2">
              <input
                type="text"
                value={newTaskName}
                onChange={(e) => setNewTaskName(e.target.value)}
                placeholder="Task name"
                className="w-full bg-gray-700 rounded px-2 py-1 text-sm mb-2"
              />
              <select
                value={newTaskType}
                onChange={(e) => setNewTaskType(e.target.value)}
                className="w-full bg-gray-700 rounded px-2 py-1 text-sm mb-2"
              >
                {TASK_TYPES.map((t) => (
                  <option key={t} value={t}>
                    {t.charAt(0).toUpperCase() + t.slice(1)}
                  </option>
                ))}
              </select>
              <button
                onClick={handleCreateTask}
                className="w-full py-1 bg-green-600 rounded text-xs"
              >
                Create Task
              </button>
            </div>
          )}

          <div className="space-y-2 max-h-60 overflow-y-auto">
            {tasks.length === 0 && (
              <div className="text-gray-500 text-xs text-center py-2">
                No tasks yet
              </div>
            )}
            {tasks.map((task) => (
              <div
                key={task.id}
                onClick={() => selectTask(task.id)}
                className={`p-2 rounded cursor-pointer transition ${
                  selectedTaskId === task.id
                    ? 'bg-blue-900/50 border border-blue-500'
                    : 'bg-gray-800 hover:bg-gray-700'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium">{task.name}</span>
                  <span
                    className={`px-2 py-0.5 rounded text-xs ${
                      STATUS_COLORS[task.status] || 'bg-gray-500'
                    }`}
                  >
                    {task.status.replace('_', ' ')}
                  </span>
                </div>
                <div className="text-xs text-gray-400 mt-1">
                  {task.task_type.charAt(0).toUpperCase() + task.task_type.slice(1)}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Selected Task Actions */}
      {selectedTask && (
        <div className="mt-4 pt-4 border-t border-gray-700">
          <h3 className="font-medium mb-2">{selectedTask.name}</h3>
          <div className="flex flex-wrap gap-2">
            {selectedTask.status === 'pending' && (
              <button
                onClick={() => updateTaskStatus(selectedTask.id, 'in_progress')}
                className="px-2 py-1 bg-blue-600 rounded text-xs"
              >
                Start
              </button>
            )}
            {selectedTask.status === 'in_progress' && (
              <>
                <button
                  onClick={() => updateTaskStatus(selectedTask.id, 'paused')}
                  className="px-2 py-1 bg-yellow-600 rounded text-xs"
                >
                  Pause
                </button>
                <button
                  onClick={() => updateTaskStatus(selectedTask.id, 'completed')}
                  className="px-2 py-1 bg-green-600 rounded text-xs"
                >
                  Complete
                </button>
              </>
            )}
            {selectedTask.status === 'paused' && (
              <button
                onClick={() => updateTaskStatus(selectedTask.id, 'in_progress')}
                className="px-2 py-1 bg-blue-600 rounded text-xs"
              >
                Resume
              </button>
            )}
            <button
              onClick={() => deleteTask(selectedTask.id)}
              className="px-2 py-1 bg-red-600 rounded text-xs"
            >
              Delete
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
