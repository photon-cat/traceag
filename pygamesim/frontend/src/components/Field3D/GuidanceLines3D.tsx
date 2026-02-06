import { useMemo } from 'react';
import * as THREE from 'three';
import type { GuidanceLine } from '../../types/simulation';

interface GuidanceLines3DProps {
  lines: GuidanceLine[];
}

export function GuidanceLines3D({ lines }: GuidanceLines3DProps) {
  const { activeLines, inactiveLines } = useMemo(() => {
    const active: THREE.Vector3[] = [];
    const inactive: THREE.Vector3[] = [];

    for (const line of lines) {
      const points = [
        new THREE.Vector3(line.x1, 0.05, -line.y1),
        new THREE.Vector3(line.x2, 0.05, -line.y2),
      ];

      if (line.active) {
        active.push(...points);
      } else {
        inactive.push(...points);
      }
    }

    return {
      activeLines: active,
      inactiveLines: inactive,
    };
  }, [lines]);

  return (
    <>
      {/* Inactive guidance lines (orange/yellow) */}
      {inactiveLines.length > 0 && (
        <lineSegments>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              count={inactiveLines.length}
              array={new Float32Array(inactiveLines.flatMap((v) => [v.x, v.y, v.z]))}
              itemSize={3}
            />
          </bufferGeometry>
          <lineBasicMaterial color="#f59e0b" linewidth={1} transparent opacity={0.6} />
        </lineSegments>
      )}

      {/* Active guidance line (bright green) */}
      {activeLines.length > 0 && (
        <lineSegments>
          <bufferGeometry>
            <bufferAttribute
              attach="attributes-position"
              count={activeLines.length}
              array={new Float32Array(activeLines.flatMap((v) => [v.x, v.y, v.z]))}
              itemSize={3}
            />
          </bufferGeometry>
          <lineBasicMaterial color="#22c55e" linewidth={2} />
        </lineSegments>
      )}
    </>
  );
}
