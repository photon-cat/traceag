import { useEffect, useRef, useCallback } from 'react';
import { useSimulationStore } from '../stores/simulationStore';
import type { SimulationState, CoverageStrip, GuidanceLine } from '../types/simulation';

const WS_URL = import.meta.env.DEV
  ? 'ws://localhost:8001/ws'
  : `ws://${window.location.host}/ws`;

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number>();
  const controlIntervalRef = useRef<number>();

  const {
    setConnected,
    setState,
    setCoverage,
    addCoverage,
    setGuidanceLines,
    setWs,
    throttle,
    steering,
  } = useSimulationStore();

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(WS_URL);

    ws.onopen = () => {
      console.log('WebSocket connected');
      setConnected(true);
      setWs(ws);
    };

    ws.onclose = () => {
      console.log('WebSocket disconnected');
      setConnected(false);
      setWs(null);

      // Reconnect after 1 second
      reconnectTimeoutRef.current = window.setTimeout(() => {
        connect();
      }, 1000);
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    ws.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);

        switch (message.type) {
          case 'init':
            // Initial state when connecting
            setState(message.data.state as SimulationState);
            if (message.data.coverage) {
              setCoverage(
                (message.data.coverage as (CoverageStrip | null)[]).filter(
                  (s): s is CoverageStrip => s !== null
                )
              );
            }
            if (message.data.guidanceLines) {
              setGuidanceLines(message.data.guidanceLines as GuidanceLine[]);
            }
            break;

          case 'state':
            // Regular state update
            setState(message.data as SimulationState);
            break;

          case 'event':
            // Handle events
            if (message.event === 'bPointSet' && message.success && message.guidanceLines) {
              setGuidanceLines(message.guidanceLines as GuidanceLine[]);
            } else if (message.event === 'guidanceCleared') {
              setGuidanceLines([]);
            } else if (message.event === 'reset') {
              setCoverage([]);
              setGuidanceLines([]);
            }
            break;

          case 'coverage':
            // Coverage update
            if (message.data) {
              addCoverage(
                (message.data as (CoverageStrip | null)[]).filter(
                  (s): s is CoverageStrip => s !== null
                )
              );
            }
            break;

          case 'guidanceLines':
            // Guidance lines update
            if (message.data) {
              setGuidanceLines(message.data as GuidanceLine[]);
            }
            break;
        }
      } catch (e) {
        console.error('Failed to parse WebSocket message:', e);
      }
    };

    wsRef.current = ws;
  }, [setConnected, setState, setCoverage, addCoverage, setGuidanceLines, setWs]);

  // Connect on mount
  useEffect(() => {
    connect();

    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  // Send control inputs at 30Hz
  useEffect(() => {
    controlIntervalRef.current = window.setInterval(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        wsRef.current.send(
          JSON.stringify({
            type: 'control',
            throttle,
            steering,
          })
        );
      }
    }, 1000 / 30);

    return () => {
      if (controlIntervalRef.current) {
        clearInterval(controlIntervalRef.current);
      }
    };
  }, [throttle, steering]);

  // Request guidance lines periodically when we have an AB line
  useEffect(() => {
    const state = useSimulationStore.getState().state;
    if (!state?.guidance.abLine) return;

    const interval = setInterval(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({ type: 'getGuidanceLines' }));
      }
    }, 500);

    return () => clearInterval(interval);
  }, []);

  return { connect };
}
