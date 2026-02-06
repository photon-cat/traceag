import { useMemo } from 'react';
import * as THREE from 'three';

interface Ground3DProps {
  size?: number;
}

export function Ground3D({ size = 500 }: Ground3DProps) {
  // Create a simple textured ground
  const groundTexture = useMemo(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 512;
    const ctx = canvas.getContext('2d')!;

    // Base brown/soil color
    ctx.fillStyle = '#5c4033';
    ctx.fillRect(0, 0, 512, 512);

    // Add some noise/texture
    for (let i = 0; i < 2000; i++) {
      const x = Math.random() * 512;
      const y = Math.random() * 512;
      const shade = Math.random() * 30 - 15;
      ctx.fillStyle = `rgb(${92 + shade}, ${64 + shade}, ${51 + shade})`;
      ctx.fillRect(x, y, 3, 3);
    }

    const texture = new THREE.CanvasTexture(canvas);
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(size / 10, size / 10);

    return texture;
  }, [size]);

  return (
    <>
      {/* Ground plane */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]} receiveShadow>
        <planeGeometry args={[size, size]} />
        <meshStandardMaterial map={groundTexture} />
      </mesh>

      {/* Grid lines for reference */}
      <gridHelper
        args={[size, size / 10, '#666666', '#444444']}
        position={[0, 0.01, 0]}
      />
    </>
  );
}

export function Sky() {
  return (
    <>
      {/* Simple gradient sky using a large sphere */}
      <mesh>
        <sphereGeometry args={[400, 32, 32]} />
        <meshBasicMaterial color="#87ceeb" side={THREE.BackSide} />
      </mesh>

      {/* Horizon fog effect */}
      <fog attach="fog" args={['#c9e4f5', 100, 400]} />
    </>
  );
}
