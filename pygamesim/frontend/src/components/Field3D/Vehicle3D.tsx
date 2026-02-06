import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import type { Pose } from '../../types/simulation';

interface Vehicle3DProps {
  pose: Pose;
  steeringAngle: number;
}

export function Vehicle3D({ pose, steeringAngle }: Vehicle3DProps) {
  const groupRef = useRef<THREE.Group>(null);
  const wheelFLRef = useRef<THREE.Group>(null);
  const wheelFRRef = useRef<THREE.Group>(null);

  useFrame(() => {
    if (!groupRef.current) return;

    // Position and rotation (convert from ENU to Three.js coordinate system)
    // In simulation: x=East, y=North, heading from North clockwise
    // In Three.js: x=right, z=forward (negative), y=up
    groupRef.current.position.set(pose.x, 0.5, -pose.y);
    groupRef.current.rotation.y = pose.heading;

    // Animate front wheels steering
    if (wheelFLRef.current) {
      wheelFLRef.current.rotation.y = steeringAngle;
    }
    if (wheelFRRef.current) {
      wheelFRRef.current.rotation.y = steeringAngle;
    }
  });

  const wheelGeometry = new THREE.CylinderGeometry(0.4, 0.4, 0.3, 16);
  const wheelMaterial = new THREE.MeshStandardMaterial({ color: '#1a1a1a' });
  const bodyMaterial = new THREE.MeshStandardMaterial({ color: '#22c55e' });
  const cabMaterial = new THREE.MeshStandardMaterial({ color: '#1e3a5f' });

  return (
    <group ref={groupRef}>
      {/* Main body */}
      <mesh position={[0, 0.3, 0]} material={bodyMaterial}>
        <boxGeometry args={[1.8, 0.8, 3.5]} />
      </mesh>

      {/* Hood */}
      <mesh position={[0, 0.5, 1.2]} material={bodyMaterial}>
        <boxGeometry args={[1.4, 0.4, 1.2]} />
      </mesh>

      {/* Cab */}
      <mesh position={[0, 1.0, -0.3]} material={cabMaterial}>
        <boxGeometry args={[1.6, 1.0, 1.4]} />
      </mesh>

      {/* Front left wheel */}
      <group position={[-1.0, 0, 1.0]} ref={wheelFLRef}>
        <mesh rotation={[0, 0, Math.PI / 2]} geometry={wheelGeometry} material={wheelMaterial} />
      </group>

      {/* Front right wheel */}
      <group position={[1.0, 0, 1.0]} ref={wheelFRRef}>
        <mesh rotation={[0, 0, Math.PI / 2]} geometry={wheelGeometry} material={wheelMaterial} />
      </group>

      {/* Rear left wheel (larger) */}
      <mesh position={[-1.0, 0.1, -1.2]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.6, 0.6, 0.4, 16]} />
        <meshStandardMaterial color="#1a1a1a" />
      </mesh>

      {/* Rear right wheel (larger) */}
      <mesh position={[1.0, 0.1, -1.2]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.6, 0.6, 0.4, 16]} />
        <meshStandardMaterial color="#1a1a1a" />
      </mesh>

      {/* Antenna mast */}
      <mesh position={[0, 1.8, 0.2]}>
        <cylinderGeometry args={[0.03, 0.03, 1.0, 8]} />
        <meshStandardMaterial color="#666666" />
      </mesh>

      {/* Antenna dome */}
      <mesh position={[0, 2.3, 0.2]}>
        <sphereGeometry args={[0.12, 16, 16]} />
        <meshStandardMaterial color="#ffffff" />
      </mesh>
    </group>
  );
}
