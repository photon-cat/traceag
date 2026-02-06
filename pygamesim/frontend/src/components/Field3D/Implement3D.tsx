import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import type { Pose } from '../../types/simulation';

interface Implement3DProps {
  pose: Pose;
  width: number;
  active: boolean;
  hitchPose: Pose;
}

export function Implement3D({ pose, width, active, hitchPose }: Implement3DProps) {
  const groupRef = useRef<THREE.Group>(null);
  const drawbarRef = useRef<THREE.Mesh>(null);

  useFrame(() => {
    if (!groupRef.current) return;

    // Position implement at its pose (work point)
    // Convert: sim x=East, y=North -> Three.js x=East, z=-North
    groupRef.current.position.set(pose.x, 0.3, -pose.y);
    // Rotation: sim heading is from North clockwise, Three.js rotation.y is CCW from +Z
    groupRef.current.rotation.y = pose.heading;

    // Update drawbar to connect hitch to implement
    if (drawbarRef.current) {
      const hx = hitchPose.x;
      const hz = -hitchPose.y;

      // The tongue/drawbar connects to a point forward of the implement center
      // (forward in implement's local coords = +Z in Three.js after rotation)
      const tongueLength = 3.0; // Distance from work point to tongue connection
      const ix = pose.x + Math.sin(pose.heading) * tongueLength;
      const iz = -pose.y - Math.cos(pose.heading) * tongueLength;

      const midX = (hx + ix) / 2;
      const midZ = (hz + iz) / 2;
      const dx = ix - hx;
      const dz = iz - hz;
      const length = Math.sqrt(dx * dx + dz * dz);
      const angle = Math.atan2(dx, dz);

      drawbarRef.current.position.set(midX, 0.35, midZ);
      drawbarRef.current.rotation.y = angle;
      drawbarRef.current.scale.z = Math.max(0.1, length);
    }
  });

  const halfWidth = width / 2;
  const numNozzles = Math.floor(width / 0.5);
  const nozzleSpacing = width / numNozzles;

  return (
    <>
      {/* Drawbar (connects hitch to implement tongue) */}
      <mesh ref={drawbarRef}>
        <boxGeometry args={[0.08, 0.08, 1]} />
        <meshStandardMaterial color="#374151" />
      </mesh>

      {/* Implement group - positioned at work point, rotated to heading */}
      <group ref={groupRef}>
        {/* Main spray boom - perpendicular to travel direction (along local X axis) */}
        <mesh position={[0, 0.2, 0]}>
          <boxGeometry args={[width, 0.12, 0.15]} />
          <meshStandardMaterial color="#4b5563" />
        </mesh>

        {/* Center frame/tank */}
        <mesh position={[0, 0.1, 1.5]}>
          <boxGeometry args={[1.2, 0.5, 2.5]} />
          <meshStandardMaterial color="#374151" />
        </mesh>

        {/* Tongue connection point */}
        <mesh position={[0, 0.15, 3]}>
          <boxGeometry args={[0.3, 0.15, 0.5]} />
          <meshStandardMaterial color="#374151" />
        </mesh>

        {/* Boom fold hinges */}
        <mesh position={[-halfWidth * 0.4, 0.15, 0.5]}>
          <boxGeometry args={[0.15, 0.3, 0.8]} />
          <meshStandardMaterial color="#4b5563" />
        </mesh>
        <mesh position={[halfWidth * 0.4, 0.15, 0.5]}>
          <boxGeometry args={[0.15, 0.3, 0.8]} />
          <meshStandardMaterial color="#4b5563" />
        </mesh>

        {/* Wheels */}
        <mesh position={[-0.8, -0.1, 1.5]} rotation={[0, 0, Math.PI / 2]}>
          <cylinderGeometry args={[0.35, 0.35, 0.2, 16]} />
          <meshStandardMaterial color="#1f2937" />
        </mesh>
        <mesh position={[0.8, -0.1, 1.5]} rotation={[0, 0, Math.PI / 2]}>
          <cylinderGeometry args={[0.35, 0.35, 0.2, 16]} />
          <meshStandardMaterial color="#1f2937" />
        </mesh>

        {/* Nozzles along the boom */}
        {Array.from({ length: numNozzles + 1 }).map((_, i) => {
          const x = -halfWidth + i * nozzleSpacing;
          return (
            <group key={i} position={[x, 0, 0]}>
              {/* Nozzle drop tube */}
              <mesh position={[0, 0, 0]}>
                <cylinderGeometry args={[0.02, 0.02, 0.25, 8]} />
                <meshStandardMaterial color={active ? '#22c55e' : '#6b7280'} />
              </mesh>
              {/* Nozzle tip */}
              <mesh position={[0, -0.15, 0]}>
                <coneGeometry args={[0.04, 0.08, 8]} />
                <meshStandardMaterial color={active ? '#22c55e' : '#6b7280'} />
              </mesh>
              {/* Spray fan when active */}
              {active && (
                <mesh position={[0, -0.35, 0]} rotation={[0, 0, 0]}>
                  <coneGeometry args={[0.25, 0.4, 8, 1, true]} />
                  <meshStandardMaterial
                    color="#60a5fa"
                    transparent
                    opacity={0.25}
                    side={THREE.DoubleSide}
                  />
                </mesh>
              )}
            </group>
          );
        })}
      </group>
    </>
  );
}
