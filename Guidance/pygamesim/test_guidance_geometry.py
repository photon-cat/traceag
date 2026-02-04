"""Geometry tests for guidance engines."""

import math
import unittest

from .guidance import ABGuidance, CurvedABGuidance, HeadlandGuidance
from .localizer import Pose


class GuidanceGeometryTests(unittest.TestCase):
    def test_straight_ab_cross_track(self) -> None:
        guidance = ABGuidance(swath_width=4.0)
        guidance.set_a_point(0.0, 0.0)
        guidance.set_b_point(0.0, 10.0)

        pose = Pose(x=2.0, y=5.0, heading=0.0)
        guidance.update(pose)

        self.assertAlmostEqual(guidance.cross_track_error, 2.0, places=3)
        self.assertEqual(guidance.active_line_index, 0)

    def test_curved_ab_on_centerline(self) -> None:
        centerline = [(0.0, 0.0), (0.0, 10.0), (10.0, 20.0)]
        guidance = CurvedABGuidance(centerline=centerline, swath_width=3.0)
        pose = Pose(x=0.0, y=5.0, heading=0.0)

        guidance.update(pose)

        self.assertAlmostEqual(guidance.cross_track_error, 0.0, places=3)
        self.assertEqual(guidance.active_line_index, 0)
        self.assertGreater(guidance.along_track_distance, 4.9)

    def test_headland_offset_ring(self) -> None:
        boundary = [(-10.0, -10.0), (10.0, -10.0), (10.0, 10.0), (-10.0, 10.0)]
        guidance = HeadlandGuidance(boundary=boundary, spacing=2.0)
        pose = Pose(x=0.0, y=8.0, heading=0.0)

        guidance.update(pose)

        self.assertAlmostEqual(guidance.cross_track_error, 0.0, places=3)
        self.assertEqual(guidance.active_ring_index, -1)


if __name__ == "__main__":
    unittest.main()
