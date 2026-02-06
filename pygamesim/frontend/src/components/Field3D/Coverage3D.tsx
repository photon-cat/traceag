import { useMemo } from 'react';
import * as THREE from 'three';
import type { CoverageStrip } from '../../types/simulation';

interface Coverage3DProps {
  strips: CoverageStrip[];
}

export function Coverage3D({ strips }: Coverage3DProps) {
  const geometry = useMemo(() => {
    if (strips.length < 2) return null;

    const vertices: number[] = [];
    const indices: number[] = [];
    const colors: number[] = [];

    // Create a mesh from coverage strips
    // Each strip creates a quad connecting to the previous strip
    for (let i = 1; i < strips.length; i++) {
      const prev = strips[i - 1];
      const curr = strips[i];

      if (!prev || !curr) continue;

      // Calculate perpendicular offset for strip width
      const halfWidth = curr.width / 2;

      // Previous strip corners
      const prevPerpX = Math.cos(prev.heading) * halfWidth;
      const prevPerpY = -Math.sin(prev.heading) * halfWidth;

      // Current strip corners
      const currPerpX = Math.cos(curr.heading) * halfWidth;
      const currPerpY = -Math.sin(curr.heading) * halfWidth;

      const baseIndex = vertices.length / 3;

      // Add 4 vertices for the quad
      // Previous left
      vertices.push(prev.x - prevPerpX, 0.02, -(prev.y - prevPerpY));
      // Previous right
      vertices.push(prev.x + prevPerpX, 0.02, -(prev.y + prevPerpY));
      // Current left
      vertices.push(curr.x - currPerpX, 0.02, -(curr.y - currPerpY));
      // Current right
      vertices.push(curr.x + currPerpX, 0.02, -(curr.y + currPerpY));

      // Add colors (green with slight variation)
      const green = 0.7 + Math.random() * 0.1;
      for (let j = 0; j < 4; j++) {
        colors.push(0.1, green, 0.2);
      }

      // Add indices for two triangles
      indices.push(
        baseIndex, baseIndex + 2, baseIndex + 1,
        baseIndex + 1, baseIndex + 2, baseIndex + 3
      );
    }

    if (vertices.length === 0) return null;

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.setIndex(indices);
    geo.computeVertexNormals();

    return geo;
  }, [strips]);

  if (!geometry) return null;

  return (
    <mesh geometry={geometry}>
      <meshStandardMaterial
        vertexColors
        side={THREE.DoubleSide}
        transparent
        opacity={0.85}
      />
    </mesh>
  );
}
