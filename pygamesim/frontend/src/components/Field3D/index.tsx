import { useRef } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { useSimulationStore } from '../../stores/simulationStore';
import { Vehicle3D } from './Vehicle3D';
import { Implement3D } from './Implement3D';
import { Coverage3D } from './Coverage3D';
import { GuidanceLines3D } from './GuidanceLines3D';
import { Ground3D, Sky } from './Ground3D';

function CameraController() {
  const { camera } = useThree();
  const state = useSimulationStore((s) => s.state);
  const targetRef = useRef(new THREE.Vector3());
  const positionRef = useRef(new THREE.Vector3(0, 30, 50));

  useFrame(() => {
    if (!state?.localizer.machine) return;

    const { x, y, heading } = state.localizer.machine;

    // Target position (where camera looks)
    const targetX = x;
    const targetZ = -y;
    targetRef.current.lerp(new THREE.Vector3(targetX, 0, targetZ), 0.05);

    // Camera position (behind and above vehicle)
    const distance = 40;
    const height = 25;
    const camX = x - Math.sin(heading) * distance;
    const camZ = -y + Math.cos(heading) * distance;
    positionRef.current.lerp(new THREE.Vector3(camX, height, camZ), 0.03);

    camera.position.copy(positionRef.current);
    camera.lookAt(targetRef.current);
  });

  return null;
}

function Scene() {
  const state = useSimulationStore((s) => s.state);
  const coverage = useSimulationStore((s) => s.coverage);
  const guidanceLines = useSimulationStore((s) => s.guidanceLines);

  if (!state) {
    return null;
  }

  const { localizer, vehicle, implement } = state;

  return (
    <>
      {/* Lighting */}
      <ambientLight intensity={0.6} />
      <directionalLight
        position={[50, 100, 50]}
        intensity={1}
        castShadow
        shadow-mapSize={[2048, 2048]}
      />

      {/* Environment */}
      <Sky />
      <Ground3D />

      {/* Coverage */}
      <Coverage3D strips={coverage} />

      {/* Guidance lines */}
      <GuidanceLines3D lines={guidanceLines} />

      {/* Vehicle */}
      <Vehicle3D
        pose={localizer.machine}
        steeringAngle={vehicle.steeringAngle}
      />

      {/* Implement */}
      <Implement3D
        pose={localizer.implement}
        width={implement.width}
        active={implement.active}
        hitchPose={localizer.hitch}
      />

      {/* Camera controller */}
      <CameraController />
    </>
  );
}

export function Field3D() {
  return (
    <div className="absolute inset-0">
      <Canvas
        camera={{
          position: [0, 30, 50],
          fov: 60,
          near: 0.1,
          far: 1000,
        }}
        shadows
      >
        <Scene />
        <OrbitControls
          enablePan={true}
          enableZoom={true}
          enableRotate={true}
          maxPolarAngle={Math.PI / 2.1}
          minDistance={10}
          maxDistance={200}
        />
      </Canvas>
    </div>
  );
}
